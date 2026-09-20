import SwiftUI

/// Top-level flow controller for the Clean Air Defender mini-game.
///
/// Owns navigation between the mini-game's stages so `CleanAirDefenderScene`
/// only has to report "round finished, here's the result" (via
/// `CleanAirDefenderGameState`), not know anything about presentation. Also
/// owns turning today's forecast into a `GameScenario` via
/// `GameScenarioMapper` before play starts — the presenter hands over a
/// data-loading closure rather than a repository, so this feature doesn't
/// need to know about `AirQualityRepository` at all.
///
/// This feature is intentionally self-contained: it never reaches into
/// `TabRouter` or any other feature's state. The presenter (`ChallengeView`)
/// owns whether this view is on screen at all and is told via `onFinish`
/// when the user is done, exactly like a modal flow.
struct CleanAirDefenderContainerView: View {
    enum Stage: Equatable {
        case entry
        case playing
        case result(GameResult)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinish: () -> Void
    /// Returns today's current PM2.5 + forecast (+ the user's own submitted
    /// prediction, if any) if already loaded — all plain AirCast domain
    /// types — or nil if unavailable, e.g. offline with nothing cached yet.
    /// Never a second network/repository call beyond what the presenter
    /// already does for its own screen.
    let loadForecastSnapshot: () async -> (currentPM25: Double, forecast: PM25Forecast, userPredictionPM25: Double?)?
    /// Default `GameProgressService()` keeps every existing call site
    /// working unchanged; tests can inject an isolated store.
    var progressService: GameProgressStoring = GameProgressService()

    @State private var stage: Stage = .entry
    /// Starts as `.standard` and is replaced once (if) real forecast data
    /// loads — so a round started before the load finishes, or with no
    /// data available at all, still plays using the same safe default as
    /// Milestone 2 (work order §15: the demo must never fail to play).
    @State private var scenario: GameScenario = .standard
    /// Retained alongside `scenario` purely so the result screen's science
    /// recap (§19) can cite the same driver data the round's difficulty was
    /// actually derived from — never a second, independent forecast read.
    @State private var forecastScenario: ForecastScenario?
    /// The user's own submitted prediction for the same day this round's
    /// forecast is for, if any — shown on the entry screen alongside the
    /// forecast so the game visibly continues the Prediction Challenge
    /// rather than reading as an unrelated feature.
    @State private var userPredictionPM25: Double?

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .entry:
                    CleanAirDefenderEntryView(
                        forecastScenario: forecastScenario,
                        userPredictionPM25: userPredictionPM25,
                        onStart: { stage = .playing },
                        onClose: onFinish
                    )
                    .transition(stageTransition)
                case .playing:
                    CleanAirDefenderGameView(
                        scenario: scenario,
                        onRoundComplete: { result in
                            progressService.save(result)
                            stage = .result(result)
                        },
                        onExit: onFinish
                    )
                    .transition(stageTransition)
                case .result(let result):
                    CleanAirDefenderResultView(
                        result: result,
                        forecastScenario: forecastScenario,
                        onPlayAgain: { stage = .playing },
                        onBackToForecast: onFinish
                    )
                    .transition(stageTransition)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35), value: stage)
        }
        .task {
            guard let snapshot = await loadForecastSnapshot() else { return }
            let mapped = ForecastScenario.make(currentPM25: snapshot.currentPM25, forecast: snapshot.forecast)
            forecastScenario = mapped
            userPredictionPM25 = snapshot.userPredictionPM25
            scenario = GameScenarioMapper.makeGameScenario(from: mapped)
        }
    }

    /// A calm crossfade under Reduce Motion; a slightly more expressive
    /// fade+scale otherwise — never anything that reads as camera shake or
    /// large screen movement (work order §16).
    private var stageTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }
}

#Preview("Clean Air Defender — Container") {
    CleanAirDefenderContainerView(onFinish: {}, loadForecastSnapshot: { nil as (currentPM25: Double, forecast: PM25Forecast, userPredictionPM25: Double?)? })
}
