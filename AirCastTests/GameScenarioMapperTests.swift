import XCTest
@testable import AirCast

/// Covers work order §22's `GameScenarioMapper` requirements: higher PM2.5
/// maps to more intensity, missing wind/precipitation never crashes,
/// extreme values are clamped, and the mapper is deterministic.
final class GameScenarioMapperTests: XCTestCase {
    private func scenario(
        currentPM25: Double = 20,
        forecastPM25: Double,
        windContribution: Double? = nil,
        windDirection: ExplanationDriver.Direction? = nil,
        precipitationContribution: Double? = nil,
        precipitationDirection: ExplanationDriver.Direction? = nil
    ) -> ForecastScenario {
        ForecastScenario(
            currentPM25: currentPM25,
            forecastPM25: forecastPM25,
            modelVersion: "test",
            dataTimestamp: Date(),
            provenance: DataProvenance(source: "test", kind: .demo, observedOrGeneratedAt: Date()),
            windContribution: windContribution,
            windDirection: windDirection,
            precipitationContribution: precipitationContribution,
            precipitationDirection: precipitationDirection
        )
    }

    func testNilForecastFallsBackToStandard() {
        let result = GameScenarioMapper.makeGameScenario(from: nil)
        XCTAssertEqual(result, .standard)
    }

    func testHigherForecastPM25MapsToHigherIntensity() {
        let low = GameScenarioMapper.makeGameScenario(from: scenario(forecastPM25: 8))
        let high = GameScenarioMapper.makeGameScenario(from: scenario(forecastPM25: 120))

        XCTAssertEqual(low.difficulty, .easy)
        XCTAssertEqual(high.difficulty, .hard)
        XCTAssertLessThan(low.particleSpawnRate, high.particleSpawnRate)
        XCTAssertLessThan(low.heavyParticleProbability, high.heavyParticleProbability)
    }

    func testMissingWindDoesNotCrashAndUsesBaselineFrequency() {
        let result = GameScenarioMapper.makeGameScenario(from: scenario(forecastPM25: 20, windContribution: nil, windDirection: nil))
        XCTAssertEqual(result.windBoostFrequency, 0.35)
    }

    func testMissingPrecipitationDoesNotCrashAndUsesBaselineFrequency() {
        let result = GameScenarioMapper.makeGameScenario(from: scenario(forecastPM25: 20, precipitationContribution: nil, precipitationDirection: nil))
        XCTAssertEqual(result.rainBoostFrequency, 0.35)
    }

    func testExtremeValuesAreClamped() {
        let result = GameScenarioMapper.makeGameScenario(from: scenario(
            forecastPM25: 10_000,
            windContribution: 999,
            windDirection: .decreasesPM25
        ))
        XCTAssertLessThanOrEqual(result.heavyParticleProbability, 0.45)
        XCTAssertLessThanOrEqual(result.windBoostFrequency, 0.85)
    }

    func testNonReducingWindDirectionFallsBackToBaselineFrequency() {
        // A wind driver that's *increasing* PM2.5 (unusual, but possible)
        // shouldn't be treated as a strong "protect me" cue the same way a
        // decreasing one is — it still gets the modest teaching baseline.
        let result = GameScenarioMapper.makeGameScenario(from: scenario(
            forecastPM25: 20,
            windContribution: 0.9,
            windDirection: .increasesPM25
        ))
        XCTAssertEqual(result.windBoostFrequency, 0.35)
    }

    func testMapperIsDeterministic() {
        let input = scenario(forecastPM25: 42, windContribution: 0.4, windDirection: .decreasesPM25, precipitationContribution: 0.2, precipitationDirection: .decreasesPM25)
        let first = GameScenarioMapper.makeGameScenario(from: input)
        let second = GameScenarioMapper.makeGameScenario(from: input)
        XCTAssertEqual(first, second)
    }

    /// The round's real forecast PM2.5 must reach `GameScenario` unchanged —
    /// this is what lets `GameHUDView` show "34 µg/m³ forecast" throughout
    /// the round, not just on the entry/result screens.
    func testForecastPM25PassesThroughUnchanged() {
        let result = GameScenarioMapper.makeGameScenario(from: scenario(forecastPM25: 41.7))
        XCTAssertEqual(result.forecastPM25, 41.7)
    }

    /// Today's real PM2.5 — the "persistence" value named in the round's
    /// opening callout — must also reach `GameScenario` unchanged.
    func testCurrentPM25PassesThroughUnchanged() {
        let result = GameScenarioMapper.makeGameScenario(from: scenario(currentPM25: 22.3, forecastPM25: 30))
        XCTAssertEqual(result.currentPM25, 22.3)
    }

    /// A genuinely PM2.5-decreasing wind driver's contribution should reach
    /// the scenario as the same whole-number percent shown in the wind
    /// boost's callout — the one place this mapper is allowed to carry the
    /// literal model number through, not just a blended game-pacing value.
    func testWindContributionPercentReflectsRealValueWhenDecreasing() {
        let result = GameScenarioMapper.makeGameScenario(from: scenario(
            forecastPM25: 20,
            windContribution: 0.42,
            windDirection: .decreasesPM25
        ))
        XCTAssertEqual(result.windContributionPercent, 42)
    }

    /// Never shows a contribution percentage for a driver that isn't
    /// actually decreasing PM2.5 in this forecast — omission over a
    /// misleading number (work order §2).
    func testContributionPercentNilWhenNotDecreasing() {
        let increasing = GameScenarioMapper.makeGameScenario(from: scenario(
            forecastPM25: 20,
            windContribution: 0.42,
            windDirection: .increasesPM25
        ))
        XCTAssertNil(increasing.windContributionPercent)

        let missing = GameScenarioMapper.makeGameScenario(from: scenario(forecastPM25: 20))
        XCTAssertNil(missing.windContributionPercent)
        XCTAssertNil(missing.precipitationContributionPercent)
    }
}
