import XCTest
@testable import AirCast

/// Covers work order §22's scoring requirements: correct target score,
/// helpful-factor penalty behavior, and combo reset.
final class CleanAirDefenderGameStateTests: XCTestCase {
    /// The round-opening mechanism callout ("Today's persistence...") must
    /// be visible immediately, before any player action — this is what
    /// makes the round legible as "a playable version of the forecast
    /// model" from the very first frame.
    func testIntroCalloutIsShownImmediatelyWhenProvided() {
        let intro = GameCallout(title: "TODAY'S PERSISTENCE", message: "28 µg/m³...", tone: .info)
        let state = CleanAirDefenderGameState(duration: 40, introCallout: intro)
        XCTAssertEqual(state.activeCallout, intro)
    }

    /// No forecast data available (nil `currentPM25` upstream) means no
    /// intro callout is constructed — omission over a fabricated framing.
    func testNoIntroCalloutByDefault() {
        let state = CleanAirDefenderGameState(duration: 40)
        XCTAssertNil(state.activeCallout)
    }

    func testCorrectTargetScoreByDensity() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .light)
        XCTAssertEqual(state.score, ParticleDensity.light.points)
        XCTAssertEqual(state.particlesCleared, 1)
        XCTAssertEqual(state.heavyParticlesCleared, 0)
    }

    func testHeavyHitCountsSeparately() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .heavy)
        XCTAssertEqual(state.heavyParticlesCleared, 1)
    }

    func testComboMultiplierAppliesFromThirdHit() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .light) // combo 1: +50
        state.registerHit(density: .light) // combo 2: +50
        let beforeThird = state.score
        state.registerHit(density: .light) // combo 3: +75 (1.5x)
        XCTAssertEqual(state.score - beforeThird, 75)
        XCTAssertEqual(state.maxCombo, 3)
    }

    func testComboResetsOnMissedParticle() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .light)
        state.registerHit(density: .light)
        XCTAssertEqual(state.combo, 2)
        state.registerMissedParticle()
        XCTAssertEqual(state.combo, 0)
        // Maintains max combo even after a reset.
        XCTAssertEqual(state.maxCombo, 2)
    }

    func testMissedParticleNeverPenalizesScore() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .light)
        let scoreAfterHit = state.score
        state.registerMissedParticle()
        XCTAssertEqual(state.score, scoreAfterHit, "work order §11: missing a harmful cluster must never directly punish score")
    }

    func testHelpfulFactorPenaltyAndComboReset() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .light)
        state.registerHit(density: .light)
        XCTAssertEqual(state.combo, 2)

        state.registerIncorrectHit(kind: .wind, elapsed: 1)

        XCTAssertEqual(state.score, ParticleDensity.light.points * 2 - 25)
        XCTAssertEqual(state.incorrectHits, 1)
        XCTAssertEqual(state.combo, 0, "an incorrect hit should break the combo streak")
        XCTAssertNotNil(state.activeCallout)
    }

    func testScoreNeverGoesNegative() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerIncorrectHit(kind: .rain, elapsed: 0)
        XCTAssertEqual(state.score, 0)
    }

    /// The callout's "-N" title must always match what actually got
    /// deducted, not a fixed "-25" — a floored deduction (starting score
    /// below 25) would otherwise overstate the real penalty to the player.
    func testIncorrectHitCalloutNamesActualDeductedAmountWhenFloored() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .light) // score = 50, below the full 25 isn't triggered yet
        state.registerIncorrectHit(kind: .wind, elapsed: 1) // 50 - 25 = 25, full deduction
        XCTAssertEqual(state.score, 25)
        XCTAssertEqual(state.activeCallout?.title, "-25")

        state.registerIncorrectHit(kind: .wind, elapsed: 2) // 25 - 25 = 0, still full deduction
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.activeCallout?.title, "-25")

        state.registerIncorrectHit(kind: .wind, elapsed: 3) // score already 0 — nothing left to deduct
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.activeCallout?.title, "-0")
    }

    func testBoostActivationAwardsScoreAndProtectionCount() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerBoostActivated(kind: .wind, elapsed: 1)
        XCTAssertEqual(state.score, 50)
        XCTAssertEqual(state.helpfulFactorsProtected, 1)
    }

    /// When the scene has a real contribution percentage from this round's
    /// forecast, the callout shown at the moment of activation names it —
    /// the "connect the game to the app, visibly, during play" requirement,
    /// not just on the entry/result screens.
    func testBoostActivationCalloutNamesRealContributionPercentWhenProvided() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerBoostActivated(kind: .wind, elapsed: 1, contributionPercent: 42)
        XCTAssertEqual(state.activeCallout?.message.contains("42%"), true)
    }

    /// No fabricated number when the mapper didn't supply one.
    func testBoostActivationCalloutOmitsPercentWhenNotProvided() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerBoostActivated(kind: .rain, elapsed: 1)
        XCTAssertEqual(state.activeCallout?.message.contains("%"), false)
    }

    func testMakeResultReflectsAccumulatedState() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.registerHit(density: .heavy)
        state.registerBoostActivated(kind: .rain, elapsed: 1)
        state.registerIncorrectHit(kind: .wind, elapsed: 2)

        let result = state.makeResult()
        XCTAssertEqual(result.score, state.score)
        XCTAssertEqual(result.particlesCleared, 1)
        XCTAssertEqual(result.heavyParticlesCleared, 1)
        XCTAssertEqual(result.helpfulFactorsProtected, 1)
        XCTAssertEqual(result.incorrectHits, 1)
        XCTAssertEqual(result.duration, 40)
    }

    func testNoUpdatesAfterRoundComplete() {
        let state = CleanAirDefenderGameState(duration: 40)
        state.completeRound()
        state.registerHit(density: .heavy)
        state.registerBoostActivated(kind: .wind, elapsed: 1)
        state.registerIncorrectHit(kind: .rain, elapsed: 1)
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.particlesCleared, 0)
    }
}
