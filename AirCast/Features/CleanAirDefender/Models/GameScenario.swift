import Foundation

/// Tunable parameters that shape one Clean Air Defender round.
///
/// `GameScenarioMapper` derives these numbers from real AirCast forecast
/// data (current/forecast PM2.5, wind/precipitation driver contributions).
/// Nothing here is itself a scientific claim (see work order §5): it only
/// controls game pacing — how many sprites appear, how fast, how often a
/// boost shows up.
struct GameScenario: Equatable {
    let duration: TimeInterval
    /// Average PM2.5 clusters spawned per second.
    let particleSpawnRate: Double
    /// Probability, 0...1, that a spawned cluster is `.heavy`.
    let heavyParticleProbability: Double
    /// Relative "how often should a wind boost appear," 0...1. Higher means
    /// more frequent — never a claim about actual wind speed.
    let windBoostFrequency: Double
    /// Same shape for rain.
    let rainBoostFrequency: Double
    let difficulty: GameDifficulty
    /// The AQI category/severity this round's forecast falls under — used
    /// only to pick which of AirCast's existing background visuals (the same
    /// `SmogSkylineView`/`ParticleFieldOverlay` combo Home/Forecast/Why/
    /// Challenge already use) to show behind the round, so the game visually
    /// reads as "the same sky as everywhere else in AirCast," not a
    /// disconnected arcade screen. Never a second scientific claim (§5).
    let category: AQICategory
    /// 0...1, `AQICategory.normalizedSeverity(pm25:)` of the forecast PM2.5.
    let severity: Double
    /// The forecast's actual PM2.5 value, shown directly in the round's HUD
    /// (work order §5's "game representation" boundary is about not
    /// inventing a *new* forecast — displaying the real, already-computed
    /// number more visibly during play is the opposite of that, and is what
    /// makes the round legible as "this IS the forecast" rather than only
    /// bookending it on the entry/result screens). Nil when no forecast
    /// loaded yet.
    let forecastPM25: Double?
    /// Wind's real relative contribution to *removal* in this forecast, as a
    /// whole-number percent, shown in the wind boost's callout at the exact
    /// moment the player activates it — nil whenever wind isn't a
    /// PM2.5-decreasing driver in this forecast or the data is missing,
    /// never a fabricated/default number (work order §2 statistical
    /// honesty). Same shape for `precipitationContributionPercent`.
    let windContributionPercent: Int?
    let precipitationContributionPercent: Int?
    /// Today's real observed/current PM2.5 — the actual "persistence" input
    /// to AirCast's regression model. Named in the round-opening callout
    /// ("Today's persistence: X µg/m³ carries into tomorrow unless
    /// removed") so the player sees the model's real mechanism, in its own
    /// vocabulary, before a single particle spawns — not just a generic
    /// "tap the bubbles" instruction. Nil when unavailable.
    let currentPM25: Double?

    static let standard = GameScenario(
        duration: 40,
        particleSpawnRate: 1.1,
        heavyParticleProbability: 0.18,
        windBoostFrequency: 0.5,
        rainBoostFrequency: 0.5,
        difficulty: .standard,
        category: .moderate,
        severity: 0.35,
        forecastPM25: nil,
        windContributionPercent: nil,
        precipitationContributionPercent: nil,
        currentPM25: nil
    )
}
