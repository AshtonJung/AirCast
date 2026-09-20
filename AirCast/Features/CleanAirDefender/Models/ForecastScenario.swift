import Foundation

/// A lightweight snapshot of "what AirCast currently knows" about tomorrow's
/// forecast, used only to size a Clean Air Defender round. Feeds
/// `GameScenarioMapper`; nothing reads this back into the statistical model
/// (work order §5's critical rule — this is a game representation, not a
/// new forecast).
///
/// Built entirely from `PM25Forecast`/`AirQualityObservation` — the exact
/// types every existing screen already gets from `AirQualityRepository`.
/// Deliberately *not* using `DemoAirQualityRepository`'s private
/// wind/precipitation inputs (see `ScenarioInputs` there): those aren't part
/// of the repository's public contract, so treating them as "data already
/// available in the app" would violate the statistical-honesty rule in §2
/// ("never pretend a variable is part of the forecasting model if it is not
/// actually present in the current implementation" — here, present means
/// reachable through the same protocol every other screen uses). Instead,
/// wind/precipitation are represented the way AirCast itself already
/// represents them to users: as `ExplanationDriver` relative contributions.
struct ForecastScenario: Equatable {
    let currentPM25: Double
    let forecastPM25: Double
    let modelVersion: String
    let dataTimestamp: Date
    /// The forecast point's own provenance (observed/predicted/demo +
    /// timestamp) — carried through unchanged so the result screen can show
    /// AirCast's standard `FreshnessBadge`, the same "Demo data · just now"
    /// labeling every other screen uses. Work order §15/§27: never let a
    /// demo value read as live.
    let provenance: DataProvenance

    /// Wind's relative contribution to this forecast, 0...1, straight from
    /// `ExplanationDriver.relativeContribution` for `.windSpeed`. Nil when
    /// this forecast has no wind driver at all (e.g. the stale/offline demo
    /// scenario returns no drivers) — never defaulted to a fabricated number.
    let windContribution: Double?
    let windDirection: ExplanationDriver.Direction?

    /// Same shape for precipitation.
    let precipitationContribution: Double?
    let precipitationDirection: ExplanationDriver.Direction?

    /// Builds a scenario from exactly what a view already has after calling
    /// `AirQualityRepository.forecast()` / `.recentObservations()` — no
    /// extra repository calls, no new data source. Returns nil if the
    /// forecast has no points yet (mapper falls back to a safe default).
    static func make(currentPM25: Double, forecast: PM25Forecast) -> ForecastScenario? {
        guard let tomorrow = forecast.points.first else { return nil }
        let wind = forecast.drivers.first { $0.kind == .windSpeed }
        let precipitation = forecast.drivers.first { $0.kind == .precipitation }
        return ForecastScenario(
            currentPM25: currentPM25,
            forecastPM25: tomorrow.pm25,
            modelVersion: forecast.modelVersion,
            dataTimestamp: forecast.generatedAt,
            provenance: tomorrow.provenance,
            windContribution: wind?.relativeContribution,
            windDirection: wind?.direction,
            precipitationContribution: precipitation?.relativeContribution,
            precipitationDirection: precipitation?.direction
        )
    }
}
