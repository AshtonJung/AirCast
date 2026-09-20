import Foundation
import Observation

/// One achievement a user can earn — criteria are simple, transparent, and
/// derived entirely from real submitted predictions. No arbitrary/inflated
/// badges, no social comparison.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let isUnlocked: Bool
}

/// Drives the Profile screen: prediction accuracy trend, completed
/// challenges, personal best, and a small achievement set — all computed
/// from real `PredictionChallenge` history, nothing hard-coded.
@Observable
@MainActor
final class ProfileViewModel {
    private let repository: AirQualityRepository
    private let progressService: GameProgressStoring

    private(set) var phase: LoadPhase = .loading
    private(set) var challenges: [PredictionChallenge] = []
    private(set) var gameResults: [GameResult] = []

    /// Default `GameProgressService()` keeps `ProfileViewModel(repository:)`
    /// call sites (e.g. `AppRootView`) working unchanged; tests can inject
    /// an isolated store.
    init(repository: AirQualityRepository, progressService: GameProgressStoring = GameProgressService()) {
        self.repository = repository
        self.progressService = progressService
    }

    private var resolved: [PredictionChallenge] {
        challenges.filter(\.isResolved).sorted { $0.challengeDate < $1.challengeDate }
    }

    var resolvedCount: Int { resolved.count }

    var averageScore: Double? {
        let scores = resolved.compactMap(\.userScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var bestScore: Double? {
        resolved.compactMap(\.userScore).max()
    }

    var bestAbsoluteError: Double? {
        resolved.compactMap(\.userAbsoluteError).min()
    }

    var timesBeatModel: Int {
        resolved.filter { ($0.userAbsoluteError ?? .infinity) < ($0.modelAbsoluteError ?? .infinity) }.count
    }

    /// Oldest-first, for a simple trend line.
    var scoreTrend: [(date: Date, score: Double)] {
        resolved.compactMap { challenge in
            guard let score = challenge.userScore else { return nil }
            return (challenge.challengeDate, score)
        }
    }

    var achievements: [Achievement] {
        [
            Achievement(
                id: "first",
                title: "First Prediction",
                detail: "Resolve your first prediction.",
                symbolName: "1.circle",
                isUnlocked: resolvedCount >= 1
            ),
            Achievement(
                id: "beatModel",
                title: "Beat the Model",
                detail: "Get closer to the real reading than AirCast's forecast.",
                symbolName: "trophy",
                isUnlocked: timesBeatModel >= 1
            ),
            Achievement(
                id: "sharp",
                title: "Sharp Shooter",
                detail: "Score 90 or higher on a single prediction.",
                symbolName: "scope",
                isUnlocked: (bestScore ?? 0) >= 90
            ),
            Achievement(
                id: "five",
                title: "Five Resolved",
                detail: "Resolve five predictions.",
                symbolName: "5.circle",
                isUnlocked: resolvedCount >= 5
            ),
            // Clean Air Defender badges (work order §13). One-time boolean
            // unlocks, same as the predictions above — repeat play can't
            // farm extra credit once a badge is already unlocked.
            Achievement(
                id: "cleanAirFirstRound",
                title: "Particle Defender",
                detail: "Complete your first Clean Air Defender round.",
                symbolName: "wind",
                isUnlocked: !gameResults.isEmpty
            ),
            Achievement(
                id: "cleanAirCleanSweep",
                title: "Clean Sweep",
                detail: "Finish a Clean Air Defender round with zero incorrect hits.",
                symbolName: "sparkles",
                isUnlocked: gameResults.contains { $0.particlesCleared > 0 && $0.incorrectHits == 0 }
            ),
            Achievement(
                id: "forecastScientist",
                title: "Forecast Scientist",
                detail: "Resolve a prediction and complete a Clean Air Defender round.",
                symbolName: "graduationcap",
                isUnlocked: resolvedCount >= 1 && !gameResults.isEmpty
            ),
        ]
    }

    func load() async {
        let hadData = !challenges.isEmpty
        if !hadData { phase = .loading }
        gameResults = progressService.loadResults()
        do {
            challenges = try await repository.predictionChallenges()
            phase = .loaded
        } catch {
            if !hadData {
                phase = .failed(RepositoryErrorPresentation.kind(for: error), message: RepositoryErrorPresentation.message(for: error))
            }
        }
    }
}
