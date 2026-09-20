import Foundation

/// Converts a `ForecastScenario` into `GameScenario` — the tunable knobs
/// that shape one Clean Air Defender round (spawn rate, heavy-particle odds,
/// wind/rain boost frequency, difficulty).
///
/// This is a **game representation, not a new scientific forecast** (work
/// order §5): it only decides how many sprites appear and how fast, never
/// anything shown as a statistic, and it never writes back to the forecast
/// model. Missing forecast data always falls back to `GameScenario.standard`
/// rather than crashing or fabricating a number (§15).
enum GameScenarioMapper {
    static func makeGameScenario(from forecast: ForecastScenario?) -> GameScenario {
        guard let forecast else { return .standard }

        let difficulty = difficulty(forPM25: forecast.forecastPM25)

        return GameScenario(
            duration: GameScenario.standard.duration,
            particleSpawnRate: spawnRate(for: difficulty),
            heavyParticleProbability: heavyParticleProbability(forPM25: forecast.forecastPM25),
            windBoostFrequency: boostFrequency(
                contribution: forecast.windContribution,
                direction: forecast.windDirection
            ),
            rainBoostFrequency: boostFrequency(
                contribution: forecast.precipitationContribution,
                direction: forecast.precipitationDirection
            ),
            difficulty: difficulty,
            // Same classification AQICategory.classify/normalizedSeverity
            // already used to color Home/Forecast/Why/Challenge — the
            // round's backdrop is driven by the real forecast value, not a
            // hardcoded placeholder.
            category: AQICategory.classify(pm25: forecast.forecastPM25),
            severity: AQICategory.normalizedSeverity(pm25: forecast.forecastPM25),
            forecastPM25: forecast.forecastPM25,
            windContributionPercent: contributionPercent(
                contribution: forecast.windContribution,
                direction: forecast.windDirection
            ),
            precipitationContributionPercent: contributionPercent(
                contribution: forecast.precipitationContribution,
                direction: forecast.precipitationDirection
            ),
            currentPM25: forecast.currentPM25
        )
    }

    /// Higher forecast PM2.5 → more/heavier clusters on screen. Thresholds
    /// mirror AirCast's own `AQICategory.classify` bands so "hard" in the
    /// game lines up with "worse air" everywhere else in the app.
    private static func difficulty(forPM25 pm25: Double) -> GameDifficulty {
        switch pm25 {
        case ..<12.1: return .easy
        case ..<35.5: return .standard
        default: return .hard
        }
    }

    private static func spawnRate(for difficulty: GameDifficulty) -> Double {
        switch difficulty {
        case .easy: return 0.85
        case .standard: return 1.1
        case .hard: return 1.4
        }
    }

    /// Clamped so a pathological/extreme forecast value can never push the
    /// probability outside a sane, playable 0.10...0.45 range.
    private static func heavyParticleProbability(forPM25 pm25: Double) -> Double {
        let clamped = max(0, min(pm25, 150))
        return 0.1 + (clamped / 150) * 0.35
    }

    /// How often this boost kind should appear, 0...1 (consumed by
    /// `CleanAirDefenderScene` to compute spawn cadence and the wind/rain
    /// split). A driver that meaningfully *reduces* PM2.5 with a larger
    /// relative contribution spawns its boost more often — a direct,
    /// honest link between "how much this factor matters in the forecast"
    /// and "how often the game lets you practice recognizing it," never a
    /// claim about its exact physical strength. Missing/non-reducing data
    /// still gets a modest baseline so the mechanic keeps showing up for
    /// teaching value even on a driver-light forecast.
    private static func boostFrequency(
        contribution: Double?,
        direction: ExplanationDriver.Direction?
    ) -> Double {
        guard let contribution, direction == .decreasesPM25 else { return 0.35 }
        let clamped = max(0, min(contribution, 1))
        return 0.35 + clamped * 0.5
    }

    /// The real relative-contribution percentage, shown verbatim in the
    /// boost's callout — this one *is* allowed to be the exact model number
    /// (unlike `boostFrequency` above, which deliberately blends in a
    /// baseline for pacing). Nil whenever the driver isn't a genuine
    /// PM2.5-decreasing factor in this forecast, so the callout omits the
    /// sentence entirely rather than showing an irrelevant or misleading
    /// percentage (work order §2: never invent causal certainty).
    private static func contributionPercent(
        contribution: Double?,
        direction: ExplanationDriver.Direction?
    ) -> Int? {
        guard let contribution, direction == .decreasesPM25 else { return nil }
        let clamped = max(0, min(contribution, 1))
        return Int((clamped * 100).rounded())
    }
}
