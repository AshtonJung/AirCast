import XCTest
@testable import AirCast

/// Covers work order §22's persistence requirements for
/// `GameProgressService`: save/load round-trips, and malformed/empty state
/// is handled without crashing.
final class GameProgressServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var service: GameProgressService!

    // A plain, stable suite name — not `#file` (an absolute source path),
    // which on some toolchains gets used as a literal preferences-file name
    // and leaves a stray `.plist` artifact next to this source file.
    private let suiteName = "com.aircast.tests.GameProgressServiceTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        service = GameProgressService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        service = nil
        super.tearDown()
    }

    private func makeResult(score: Int = 100, incorrectHits: Int = 0) -> GameResult {
        GameResult(
            score: score,
            particlesCleared: 10,
            heavyParticlesCleared: 2,
            helpfulFactorsProtected: 1,
            incorrectHits: incorrectHits,
            maxCombo: 3,
            duration: 40,
            playedAt: Date()
        )
    }

    func testLoadResultsIsEmptyWhenNothingStored() {
        XCTAssertTrue(service.loadResults().isEmpty)
    }

    func testSaveThenLoadRoundTrips() {
        let result = makeResult(score: 1420)
        service.save(result)
        XCTAssertEqual(service.loadResults(), [result])
    }

    func testSaveAppendsAcrossMultipleRounds() {
        service.save(makeResult(score: 100))
        service.save(makeResult(score: 200))
        let loaded = service.loadResults()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.map(\.score), [100, 200])
    }

    func testLoadResultsReturnsEmptyForMalformedData() {
        defaults.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: "cleanAirDefender.results")
        XCTAssertTrue(service.loadResults().isEmpty)
    }

    func testSaveCapsStoredHistory() {
        for index in 0..<(GameProgressService.maxStoredResults + 10) {
            service.save(makeResult(score: index))
        }
        let loaded = service.loadResults()
        XCTAssertEqual(loaded.count, GameProgressService.maxStoredResults)
        // Oldest entries should have been dropped, newest kept.
        XCTAssertEqual(loaded.last?.score, GameProgressService.maxStoredResults + 9)
    }
}
