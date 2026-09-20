import XCTest
@testable import AirCast

final class AQICategoryTests: XCTestCase {
    func testBoundaryClassification() {
        XCTAssertEqual(AQICategory.classify(pm25: 0), .good)
        XCTAssertEqual(AQICategory.classify(pm25: 12.0), .good)
        XCTAssertEqual(AQICategory.classify(pm25: 12.1), .moderate)
        XCTAssertEqual(AQICategory.classify(pm25: 35.4), .moderate)
        XCTAssertEqual(AQICategory.classify(pm25: 35.5), .unhealthyForSensitiveGroups)
        XCTAssertEqual(AQICategory.classify(pm25: 55.5), .unhealthy)
        XCTAssertEqual(AQICategory.classify(pm25: 150.5), .veryUnhealthy)
        XCTAssertEqual(AQICategory.classify(pm25: 250.5), .hazardous)
        XCTAssertEqual(AQICategory.classify(pm25: 500), .hazardous)
    }
}

final class PredictionScoringTests: XCTestCase {
    func testZeroErrorScoresMax() {
        XCTAssertEqual(PredictionScoring.score(absoluteError: 0), 100, accuracy: 0.001)
    }

    func testScoreDecaysWithError() {
        let near = PredictionScoring.score(absoluteError: 5)
        let far = PredictionScoring.score(absoluteError: 40)
        XCTAssertGreaterThan(near, far)
        XCTAssertGreaterThan(far, 0) // near-misses are never hard-zeroed
    }

    func testScoreNeverNegativeOrAboveHundred() {
        for error in stride(from: 0.0, through: 500.0, by: 17.0) {
            let score = PredictionScoring.score(absoluteError: error)
            XCTAssertGreaterThanOrEqual(score, 0)
            XCTAssertLessThanOrEqual(score, 100)
        }
    }
}

final class DataProvenanceTests: XCTestCase {
    func testStaleDetection() {
        let fresh = DataProvenance(source: "test", kind: .observed, observedOrGeneratedAt: Date())
        XCTAssertFalse(fresh.isStale())

        let stale = DataProvenance(source: "test", kind: .observed, observedOrGeneratedAt: Date().addingTimeInterval(-3 * 3600))
        XCTAssertTrue(stale.isStale())
    }
}
