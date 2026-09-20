import XCTest
@testable import AirCast

/// Covers the "Reset Demo" contract that Settings' destructive button relies
/// on: after switching scenario and submitting a prediction, resetDemo()
/// must put the repository back to a known, judge-ready starting state.
final class DemoAirQualityRepositoryTests: XCTestCase {
    func testResetDemoRestoresDefaultScenario() async throws {
        let repository = DemoAirQualityRepository(scenario: .cleanAirImproving)
        await repository.setScenario(.unhealthyLowConfidence)
        let switched = await repository.currentScenario
        XCTAssertEqual(switched, .unhealthyLowConfidence)

        await repository.resetDemo()
        let afterReset = await repository.currentScenario
        XCTAssertEqual(afterReset, .cleanAirImproving)
    }

    func testResetDemoClearsUserSubmittedPredictionsButReseedsHistoricalExample() async throws {
        let repository = DemoAirQualityRepository(scenario: .cleanAirImproving)

        // Force the seeded historical example to exist, then add a second,
        // user-submitted prediction on top of it.
        _ = try await repository.predictionChallenges()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        _ = try await repository.submitPrediction(pm25: 30, for: tomorrow)
        let beforeReset = try await repository.predictionChallenges()
        XCTAssertEqual(beforeReset.count, 2, "expected the seeded historical example plus the new submission")

        await repository.resetDemo()

        let afterReset = try await repository.predictionChallenges()
        XCTAssertEqual(afterReset.count, 1, "reset should clear user submissions but reseed the one real historical example")
        XCTAssertNotNil(afterReset.first?.resolvedAt, "the remaining challenge should be the already-resolved historical example")
    }

    func testResetDemoIsIdempotent() async throws {
        let repository = DemoAirQualityRepository(scenario: .staleOffline)
        await repository.resetDemo()
        await repository.resetDemo()
        let scenario = await repository.currentScenario
        XCTAssertEqual(scenario, .cleanAirImproving)
    }
}
