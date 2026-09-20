import Foundation

/// Snapshot of one completed Clean Air Defender round, built from
/// `CleanAirDefenderGameState` when a round ends.
///
/// Lives in the app's shared `Models/` (next to `PredictionChallenge`)
/// rather than under `Features/CleanAirDefender/` because — like
/// `PredictionChallenge` — more than one feature now depends on it:
/// `CleanAirDefenderContainerView` writes it via `GameProgressService`, and
/// `ProfileViewModel` reads the saved history to compute achievements.
struct GameResult: Codable, Equatable {
    let score: Int
    let particlesCleared: Int
    let heavyParticlesCleared: Int
    /// Wind/rain boosts activated by dragging through them (work order §9 B/C).
    let helpfulFactorsProtected: Int
    /// Boosts tapped like a threat instead — the "incorrectly attacks a
    /// helpful factor" mistake from work order §4 step 4.
    let incorrectHits: Int
    let maxCombo: Int
    let duration: TimeInterval
    let playedAt: Date
}
