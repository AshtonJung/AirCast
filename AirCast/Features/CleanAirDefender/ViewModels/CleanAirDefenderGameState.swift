import Foundation
import Observation

/// Live state for one Clean Air Defender round.
///
/// `CleanAirDefenderScene` (SpriteKit) mutates this on every hit/miss/tick;
/// `CleanAirDefenderGameView` (SwiftUI) observes it directly for the HUD and
/// the haze overlay. Keeping this separate from the scene means the SwiftUI
/// side never has to reach into SpriteKit, and a future results/persistence
/// step can read the same numbers without re-deriving them.
///
/// No separate "ViewModel" wraps this for Milestone 2 — there's no
/// loading/error state or repository call to coordinate, just per-frame
/// score bookkeeping, so this `@Observable` model is the smallest coherent
/// piece. Milestone 5 (results/XP/persistence, which does talk to a
/// repository) is a more natural place for an actual view model.
@Observable
final class CleanAirDefenderGameState {
    let duration: TimeInterval

    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var timeRemaining: TimeInterval
    private(set) var particlesCleared: Int = 0
    private(set) var heavyParticlesCleared: Int = 0
    private(set) var helpfulFactorsProtected: Int = 0
    private(set) var incorrectHits: Int = 0
    /// 0 (clear sky) ... 1 (fully hazy). Rises when clusters are missed,
    /// falls when clusters are cleared — the visible "dirty → clean" signal
    /// required by work order §7. Also drives the live `SmogSkylineView`
    /// backdrop's fog severity, so "less hazy" isn't just a tinted overlay —
    /// it's the same fog effect Home/Forecast/Why/Challenge already use.
    private(set) var hazeLevel: Double
    private(set) var isRoundComplete: Bool = false
    private(set) var isPaused: Bool = false
    /// The most recent wind/rain educational callout, if one hasn't expired
    /// yet. `CleanAirDefenderScene` clears this once its `elapsed` time
    /// passes `calloutExpiresAt` — kept as scene-time rather than a Task/
    /// timer so it stays on the same synchronous update loop as everything
    /// else here (no actor-isolation concerns mixing with SpriteKit).
    private(set) var activeCallout: GameCallout?
    private var calloutExpiresAt: TimeInterval?

    /// `initialHazeLevel` should come from the round's real forecast
    /// severity (`GameScenario.severity`, clamped to a playable range) so a
    /// round generated from a genuinely hazy forecast visibly starts hazier
    /// — not a fixed placeholder regardless of what the forecast says.
    /// Defaults to the previous fixed value so existing call sites/tests are
    /// unaffected.
    ///
    /// `introCallout`, when provided, is shown immediately (not triggered by
    /// any player action) so the very first thing the player sees is the
    /// round's real mechanism framing — "today's persistence carries into
    /// tomorrow unless removed" — before a single particle has spawned.
    /// Shown longer than a reaction callout (2.6s vs. 1.6s) since it's
    /// context-setting, not a quick response cue.
    init(duration: TimeInterval, initialHazeLevel: Double = 0.35, introCallout: GameCallout? = nil) {
        self.duration = duration
        self.timeRemaining = duration
        self.hazeLevel = initialHazeLevel
        if let introCallout {
            self.activeCallout = introCallout
            self.calloutExpiresAt = 2.6
        }
    }

    /// Returns the points actually awarded for this hit (post-combo
    /// multiplier) so the scene can show an accurate "+N" popup at the hit
    /// location without recomputing the scoring formula itself — one
    /// scoring formula, in one place (work order §24: no duplicated scoring
    /// logic).
    @discardableResult
    func registerHit(density: ParticleDensity) -> Int {
        guard !isRoundComplete else { return 0 }
        combo += 1
        maxCombo = max(maxCombo, combo)
        // Small combo multiplier per work order §11 ("3-hit combo — small multiplier").
        let comboMultiplier = combo >= 3 ? 1.5 : 1.0
        let awarded = Int((Double(density.points) * comboMultiplier).rounded())
        score += awarded
        particlesCleared += 1
        if density == .heavy { heavyParticlesCleared += 1 }
        hazeLevel = max(0, hazeLevel - hazeReduction(for: density))
        return awarded
    }

    /// A cluster drifted off screen unhit. Work order §11: "no direct
    /// punishment" — so this never touches score, only resets the combo
    /// streak and nudges the haze layer back up slightly.
    func registerMissedParticle() {
        guard !isRoundComplete else { return }
        combo = 0
        hazeLevel = min(1, hazeLevel + 0.04)
    }

    /// The player dragged through a boost — the correct "protect/activate"
    /// interaction (work order §11: +50). `contributionPercent`, when
    /// available, names this driver's real contribution to removal in the
    /// round's actual forecast (see `GameTargetType.activationCallout(contributionPercent:)`);
    /// defaults to nil so existing call sites/tests are unaffected.
    func registerBoostActivated(kind: EnvironmentalBoostKind, elapsed: TimeInterval, contributionPercent: Int? = nil) {
        guard !isRoundComplete else { return }
        score += 50
        helpfulFactorsProtected += 1
        showCallout(kind.activationCallout(contributionPercent: contributionPercent), elapsed: elapsed)
    }

    /// A boost cleared some on-screen particles on the player's behalf
    /// (work order §9 B/C: wind "sweeps particles away," rain "removes some
    /// active PM2.5 clusters"). Not a tap-clear — no score/combo credit,
    /// since the player didn't aim it — but it does reduce haze, matching
    /// the visible sweep effect.
    func registerEnvironmentalSweep(particleCount: Int) {
        guard !isRoundComplete, particleCount > 0 else { return }
        hazeLevel = max(0, hazeLevel - Double(particleCount) * 0.015)
    }

    /// The player tapped a boost like a threat instead of dragging through
    /// it — work order §4 step 4's "incorrectly attacks a helpful factor"
    /// (§11: -25, never below zero; avoid highly punishing mechanics).
    func registerIncorrectHit(kind: EnvironmentalBoostKind, elapsed: TimeInterval) {
        guard !isRoundComplete else { return }
        // Compute what actually got deducted (never below zero) *before*
        // applying it, so the callout can name the real amount instead of
        // a fixed "-25" that would overstate the penalty for a low score.
        let deducted = min(25, score)
        score -= deducted
        incorrectHits += 1
        combo = 0
        showCallout(kind.incorrectHitCallout(deducted: deducted), elapsed: elapsed)
    }

    private func showCallout(_ callout: GameCallout, elapsed: TimeInterval) {
        activeCallout = callout
        calloutExpiresAt = elapsed + 1.6
    }

    /// Called every scene update tick; clears `activeCallout` once its
    /// display window has passed.
    func expireCalloutIfNeeded(elapsed: TimeInterval) {
        guard let expiresAt = calloutExpiresAt, elapsed >= expiresAt else { return }
        activeCallout = nil
        calloutExpiresAt = nil
    }

    func tick(remaining: TimeInterval) {
        guard !isRoundComplete else { return }
        timeRemaining = max(0, remaining)
    }

    func completeRound() {
        isRoundComplete = true
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    func makeResult() -> GameResult {
        GameResult(
            score: score,
            particlesCleared: particlesCleared,
            heavyParticlesCleared: heavyParticlesCleared,
            helpfulFactorsProtected: helpfulFactorsProtected,
            incorrectHits: incorrectHits,
            maxCombo: maxCombo,
            duration: duration,
            playedAt: Date()
        )
    }

    private func hazeReduction(for density: ParticleDensity) -> Double {
        switch density {
        case .light: return 0.02
        case .medium: return 0.035
        case .heavy: return 0.055
        }
    }
}
