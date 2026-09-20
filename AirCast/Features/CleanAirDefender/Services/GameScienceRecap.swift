import Foundation

/// Builds the 1–3 short science takeaways shown on the result screen (work
/// order §19). Every line is generated only from fields actually present in
/// the `ForecastScenario` that shaped this round — if a driver wasn't part
/// of this forecast, its sentence is omitted rather than invented ("If data
/// is missing, omit the explanation rather than inventing one").
enum GameScienceRecap {
    /// `result` is this specific round's actual performance — used only to
    /// name what the player just did in the model's own vocabulary
    /// (persistence cleared / removal protected), never to alter or feed
    /// into the real forecast (work order §5). `scenario` drives the
    /// existing driver-specific lines below, unchanged.
    static func takeaways(for scenario: ForecastScenario?, result: GameResult) -> [String] {
        var lines: [String] = [mechanismSummary(for: result)]

        guard let scenario else { return lines }

        if scenario.windDirection == .decreasesPM25 {
            lines.append("Wind can increase particle dispersion in AirCast's removal framework.")
        }
        if scenario.precipitationDirection == .decreasesPM25 {
            lines.append("Precipitation can remove airborne particles through wet deposition.")
        }
        if AQICategory.classify(pm25: scenario.currentPM25) != .good {
            lines.append("Today's particle load can contribute to persistence into the next forecast period.")
        }

        return Array(lines.prefix(4))
    }

    /// States the round in the exact terms the round-opening callout and
    /// the in-game HUD already used ("persistence" / "removal") — this is
    /// the line meant to make "this game is a playable version of the
    /// forecast model" land immediately, using this specific round's real
    /// numbers rather than generic language.
    private static func mechanismSummary(for result: GameResult) -> String {
        let clusterWord = result.particlesCleared == 1 ? "cluster" : "clusters"
        let boostWord = result.helpfulFactorsProtected == 1 ? "boost" : "boosts"
        return "This round: you cleared \(result.particlesCleared) particle \(clusterWord) (persistence ↓) and protected \(result.helpfulFactorsProtected) wind/rain \(boostWord) (removal ↑) — the same two forces behind AirCast's forecast."
    }
}
