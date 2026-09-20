import Foundation
import Observation

/// Whether recent PM2.5 has been trending down, up, or holding steady.
/// Computed from real observation deltas — never guessed.
enum PM25Trend: Equatable {
    case improving
    case worsening
    case steady

    var label: String {
        switch self {
        case .improving: return "Improving"
        case .worsening: return "Worsening"
        case .steady: return "Holding steady"
        }
    }

    var symbolName: String {
        switch self {
        case .improving: return "arrow.down.right"
        case .worsening: return "arrow.up.right"
        case .steady: return "arrow.right"
        }
    }
}

/// Home's view model. Owns nothing but typed domain data pulled through
/// `AirQualityRepository` — the view never touches the repository directly,
/// and never sees anything the repository didn't attach real provenance to.
@Observable
@MainActor
final class HomeViewModel {
    private let repository: AirQualityRepository

    private(set) var phase: LoadPhase = .loading
    private(set) var currentObservation: AirQualityObservation?
    private(set) var recentObservations: [AirQualityObservation] = []
    private(set) var tomorrowForecast: PM25ForecastPoint?
    private(set) var drivers: [ExplanationDriver] = []
    /// Bumped on every successful refresh (not the first load) so the view
    /// can fire a single haptic tick without re-triggering on initial load.
    private(set) var refreshTicks: Int = 0

    init(repository: AirQualityRepository) {
        self.repository = repository
    }

    var trend: PM25Trend {
        guard let newest = recentObservations.first, let oldest = recentObservations.last, newest.id != oldest.id else {
            return .steady
        }
        let delta = newest.pm25 - oldest.pm25
        if delta <= -1 { return .improving }
        if delta >= 1 { return .worsening }
        return .steady
    }

    var topDriver: ExplanationDriver? { drivers.first }

    /// True when the most recent observation is old enough that the demo
    /// should read as "offline / showing last saved data" rather than merely
    /// "a little stale." No live connectivity check exists yet (local-first
    /// build) — this is a conservative, honest proxy based on data age.
    var readsAsOffline: Bool {
        currentObservation?.provenance.isStale(threshold: 4 * 3600) ?? false
    }

    func load() async {
        let hadExistingData = currentObservation != nil
        if !hadExistingData { phase = .loading }
        do {
            async let observationsTask = repository.recentObservations(limit: 24)
            async let forecastTask = repository.forecast()
            let (observations, forecast) = try await (observationsTask, forecastTask)

            guard let latest = observations.first else {
                if !hadExistingData { phase = .failed(.empty, message: "No recent observations are available yet.") }
                return
            }

            currentObservation = latest
            recentObservations = observations
            tomorrowForecast = forecast.point(closestTo: Date().addingTimeInterval(24 * 3600)) ?? forecast.points.first
            drivers = forecast.drivers
            phase = .loaded
            if hadExistingData { refreshTicks += 1 }
        } catch {
            // A failed refresh keeps showing the last good data rather than
            // replacing the whole screen — only a cold-start failure (no
            // data to fall back on) surfaces the full error state.
            if !hadExistingData {
                phase = .failed(RepositoryErrorPresentation.kind(for: error), message: RepositoryErrorPresentation.message(for: error))
            }
        }
    }
}
