import XCTest
@testable import AirCast

/// Covers `GameEducationFacts` — the health-guidance and dataset-fact text
/// surfaced in Clean Air Defender, all sourced from existing real app data
/// (`AQICategory.guidance`, `BundledResearchData`), never invented.
final class GameEducationFactsTests: XCTestCase {
    func testHealthGuidanceMatchesRealAQICategoryForForecastValue() {
        let result = GameEducationFacts.healthGuidance(forecastPM25: 8)
        XCTAssertEqual(result.category, .good)
        XCTAssertEqual(result.guidance, AQICategory.good.guidance)
    }

    func testHealthGuidanceReflectsWorseForecastCategory() {
        let result = GameEducationFacts.healthGuidance(forecastPM25: 200)
        XCTAssertEqual(result.category, .veryUnhealthy)
        XCTAssertEqual(result.guidance, AQICategory.veryUnhealthy.guidance)
    }

    /// The dataset fact must cite the same real numbers
    /// `BundledResearchDataTests` already verifies against the shipped
    /// JSON — this just confirms the game's sentence actually contains them
    /// rather than a stale/rounded copy.
    func testDatasetFactCitesRealBundledNumbers() {
        let dataset = BundledResearchData.forecastModel.dataset
        let fact = GameEducationFacts.datasetFact
        XCTAssertTrue(fact.contains("\(dataset.nConsecutiveDayPairs)"))
        XCTAssertTrue(fact.contains(dataset.geography))
    }
}
