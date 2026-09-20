import XCTest
@testable import AirCast

/// Guards the bundled research JSON (`Resources/ResearchData/*.json`): if
/// packaging ever drops or corrupts these files, `BundledResearchData` would
/// otherwise only fail with a `fatalError` at first access deep inside a
/// repository call. This test catches that at build/test time instead of at
/// CAC judging time.
final class BundledResearchDataTests: XCTestCase {
    func testForecastModelDecodesAndIsSane() {
        let model = BundledResearchData.forecastModel

        XCTAssertFalse(model.dataset.sourceName.isEmpty)
        XCTAssertGreaterThan(model.dataset.nConsecutiveDayPairs, 1000)
        XCTAssertEqual(model.dataset.nTrainPairs + model.dataset.nTestPairs, model.dataset.nConsecutiveDayPairs)

        // The whole point of shipping this model: it must actually beat the
        // naive "tomorrow = today" baseline on the held-out test set, or the
        // app would be misrepresenting it as an improvement.
        let eval = model.evaluation.test
        XCTAssertNotNil(eval.baselinePersistenceMAE)
        if let baselineMAE = eval.baselinePersistenceMAE {
            XCTAssertLessThan(eval.modelMAE, baselineMAE)
        }
        XCTAssertGreaterThan(eval.n, 100)
    }

    func testRecentObservationsDecodesAndChallengeExampleIsConsistent() {
        let recent = BundledResearchData.recentObservations
        XCTAssertGreaterThan(recent.recentObservations.count, 10)

        let example = recent.challengeExample
        XCTAssertGreaterThanOrEqual(example.pm25Today, 0)
        XCTAssertGreaterThanOrEqual(example.observedNextDay, 0)
    }

    func testTestResidualsDecodeAndMatchReportedMAE() {
        let residuals = BundledResearchData.testResiduals
        XCTAssertGreaterThan(residuals.testPoints.count, 500)

        // The per-point residuals must actually average out to the MAE the
        // model card reports — otherwise Model Lab's chart and its headline
        // metric would be telling two different stories.
        let meanAbsoluteResidual = residuals.testPoints.map { abs($0.residual) }.reduce(0, +) / Double(residuals.testPoints.count)
        let reportedMAE = BundledResearchData.forecastModel.evaluation.test.modelMAE
        XCTAssertEqual(meanAbsoluteResidual, reportedMAE, accuracy: 0.01)

        for point in residuals.testPoints {
            XCTAssertEqual(point.residual, point.observed - point.predicted, accuracy: 0.011)
        }
    }
}
