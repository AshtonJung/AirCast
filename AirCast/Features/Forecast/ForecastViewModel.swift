import Foundation
import Observation

/// A single selectable point on the Forecast chart — either a real past
/// observation or a forecast point. Kept as one type so the chart, crosshair,
/// and detail card can treat both uniformly while the UI still always shows
/// which one it is (never blurs the observed/predicted line).
enum ForecastSelection: Identifiable, Equatable {
    case observation(AirQualityObservation)
    case forecast(PM25ForecastPoint)

    var id: String {
        switch self {
        case .observation(let obs): return "obs-\(obs.id.uuidString)"
        case .forecast(let point): return "fc-\(point.targetTime.timeIntervalSinceReferenceDate)"
        }
    }

    var timestamp: Date {
        switch self {
        case .observation(let obs): return obs.timestamp
        case .forecast(let point): return point.targetTime
        }
    }

    var pm25: Double {
        switch self {
        case .observation(let obs): return obs.pm25
        case .forecast(let point): return point.pm25
        }
    }

    var category: AQICategory {
        switch self {
        case .observation(let obs): return obs.category
        case .forecast(let point): return point.category
        }
    }

    var provenance: DataProvenance {
        switch self {
        case .observation(let obs): return obs.provenance
        case .forecast(let point): return point.provenance
        }
    }

    var isObserved: Bool {
        if case .observation = self { return true }
        return false
    }

    var uncertainty: ForecastUncertainty? {
        if case .forecast(let point) = self { return point.uncertainty }
        return nil
    }
}

/// Forecast screen's view model: the same repository Home uses, reshaped
/// into one chronological, selectable timeline spanning recent observations
/// through the forecast horizon.
@Observable
@MainActor
final class ForecastViewModel {
    private let repository: AirQualityRepository

    private(set) var phase: LoadPhase = .loading
    private(set) var observations: [AirQualityObservation] = [] // newest-first
    private(set) var forecast: PM25Forecast?
    private(set) var selectionTicks: Int = 0

    var selection: ForecastSelection? {
        didSet {
            guard let selection, oldValue?.id != selection.id else { return }
            selectionTicks += 1
        }
    }

    init(repository: AirQualityRepository) {
        self.repository = repository
    }

    /// Oldest-first, for chart plotting.
    var chronologicalObservations: [AirQualityObservation] { observations.reversed() }
    var forecastPoints: [PM25ForecastPoint] { forecast?.points ?? [] }
    var drivers: [ExplanationDriver] { forecast?.drivers ?? [] }
    var modelVersion: String? { forecast?.modelVersion }

    /// The selected point's PM2.5 if there is one, else the latest
    /// observation — the single source of truth for "what number is this
    /// screen currently about," used by the background, the map pin, and
    /// anywhere else that needs to agree with each other.
    var backgroundPM25: Double {
        selection?.pm25 ?? observations.first?.pm25 ?? 20
    }

    /// Drives the atmospheric background's particle density — the selected
    /// point if there is one, else the latest observation.
    var backgroundSeverity: Double {
        AQICategory.normalizedSeverity(pm25: backgroundPM25)
    }

    var backgroundCategory: AQICategory {
        selection?.category ?? observations.first?.category ?? .moderate
    }

    /// Every point on the timeline, oldest to newest, observed then forecast —
    /// used for chart drag hit-testing.
    var timeline: [ForecastSelection] {
        chronologicalObservations.map(ForecastSelection.observation) + forecastPoints.map(ForecastSelection.forecast)
    }

    /// The "headline" points only — latest observation plus each forecast
    /// day — for the compact, scannable chip selector (not every hourly
    /// observation).
    var headlinePoints: [ForecastSelection] {
        var result: [ForecastSelection] = []
        if let latest = observations.first { result.append(.observation(latest)) }
        result.append(contentsOf: forecastPoints.map(ForecastSelection.forecast))
        return result
    }

    func load() async {
        let hadData = forecast != nil
        if !hadData { phase = .loading }
        do {
            async let observationsTask = repository.recentObservations(limit: 24)
            async let forecastTask = repository.forecast()
            let (obs, fc) = try await (observationsTask, forecastTask)

            observations = obs
            forecast = fc
            if selection == nil, let firstForecast = fc.points.first {
                selection = .forecast(firstForecast)
            }
            phase = .loaded
        } catch {
            if !hadData {
                phase = .failed(RepositoryErrorPresentation.kind(for: error), message: RepositoryErrorPresentation.message(for: error))
            }
        }
    }

    func select(closestTo date: Date) {
        guard let closest = timeline.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }) else { return }
        selection = closest
    }
}
