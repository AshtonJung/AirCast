import Foundation
import Observation

/// Drives the full "Why this forecast?" screen: every ranked driver (not just
/// the Home/Forecast strip's top 3), a real "what changed since you last
/// looked" comparison, and the model card used for the "How AirCast knows"
/// disclosure.
@Observable
@MainActor
final class WhyViewModel {
    private let repository: AirQualityRepository

    private(set) var phase: LoadPhase = .loading
    private(set) var forecast: PM25Forecast?
    private(set) var modelCard: ModelCard?
    /// The driver set from the *previous* successful load in this session —
    /// not a fabricated "yesterday's forecast run." Comparisons are labeled
    /// accordingly ("since your last refresh"), because that is exactly what
    /// was actually computed.
    private(set) var previousDrivers: [ExplanationDriver]?
    private(set) var lastLoadedAt: Date?

    init(repository: AirQualityRepository) {
        self.repository = repository
    }

    var drivers: [ExplanationDriver] { forecast?.drivers ?? [] }
    var tomorrowPoint: PM25ForecastPoint? { forecast?.points.first }
    var hasComparison: Bool { previousDrivers != nil }
    var backgroundCategory: AQICategory { tomorrowPoint?.category ?? .moderate }
    var backgroundPM25: Double { tomorrowPoint?.pm25 ?? 20 }
    var backgroundSeverity: Double { AQICategory.normalizedSeverity(pm25: backgroundPM25) }

    func load() async {
        let hadData = forecast != nil
        if !hadData { phase = .loading }
        do {
            async let forecastTask = repository.forecast()
            async let modelCardTask = repository.modelCard()
            let (fc, card) = try await (forecastTask, modelCardTask)

            if hadData { previousDrivers = forecast?.drivers }
            forecast = fc
            modelCard = card
            lastLoadedAt = Date()
            phase = .loaded
        } catch {
            if !hadData {
                phase = .failed(RepositoryErrorPresentation.kind(for: error), message: RepositoryErrorPresentation.message(for: error))
            }
        }
    }

    /// A short, honest, non-causal change description for one driver,
    /// derived from a real diff against the previous load — or `nil` if
    /// there's nothing to compare yet (first load) or no meaningful change.
    func changeDescription(for driver: ExplanationDriver) -> String? {
        guard let previous = previousDrivers?.first(where: { $0.kind == driver.kind }) else { return nil }

        if previous.direction != driver.direction {
            return "Direction changed since your last refresh."
        }
        guard let prevContribution = previous.relativeContribution, let currContribution = driver.relativeContribution else {
            return nil
        }
        let delta = currContribution - prevContribution
        if abs(delta) < 0.02 { return "About as influential as your last refresh." }
        return delta > 0 ? "More influential than your last refresh." : "Less influential than your last refresh."
    }

    /// One plain-language sentence a nontechnical reader can use to explain
    /// tomorrow's forecast — built only from real fields, never invented.
    var summarySentence: String {
        guard let point = tomorrowPoint else { return "Forecast details aren't available right now." }
        let trendPhrase: String
        switch point.category {
        case .good, .moderate: trendPhrase = "expected to stay relatively low"
        case .unhealthyForSensitiveGroups, .unhealthy: trendPhrase = "expected to be elevated"
        case .veryUnhealthy, .hazardous: trendPhrase = "expected to be significantly elevated"
        }
        guard let top = drivers.first else {
            return "Tomorrow's PM2.5 is \(trendPhrase), around \(Int(point.pm25.rounded())) µg/m³."
        }
        let directionPhrase = top.direction == .increasesPM25 ? "pushing it higher" : (top.direction == .decreasesPM25 ? "pushing it lower" : "with an unclear effect")
        return "Tomorrow's PM2.5 is \(trendPhrase), around \(Int(point.pm25.rounded())) µg/m³ — most associated with \(top.kind.label), \(directionPhrase)."
    }
}
