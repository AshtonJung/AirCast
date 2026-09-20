import Foundation

/// Local storage for completed Clean Air Defender rounds.
///
/// Sits alongside `AirQualityRepository` rather than under
/// `Features/CleanAirDefender/` because, like `GameResult`, more than one
/// feature depends on it: the game writes to it, `ProfileViewModel` reads
/// from it for achievements.
///
/// Deliberately the app's first and only piece of on-device persistence
/// (work order §12: "Store locally. Do not introduce login, cloud sync,
/// social accounts, or backend infrastructure for this milestone.") —
/// everything else in AirCast is intentionally in-memory/session-only so a
/// judge's `resetDemo()` always returns to a clean, known state. `UserDefaults`
/// is the simplest storage that fits a small, capped array of results.
protocol GameProgressStoring {
    func loadResults() -> [GameResult]
    func save(_ result: GameResult)
}

final class GameProgressService: GameProgressStoring {
    /// Hard cap so repeat play can't grow local storage without bound —
    /// pairs with achievements being one-time boolean unlocks (work order
    /// §13: "Do not encourage endless replay loops... cap or sharply reduce
    /// repeat rewards") rather than a farmable point counter.
    static let maxStoredResults = 50

    private let defaults: UserDefaults
    private let storageKey = "cleanAirDefender.results"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Never throws — malformed or missing data (e.g. an older app version's
    /// schema, or nothing saved yet) simply reads back as "no history,"
    /// exactly like a fresh install (work order §22: "malformed/empty state handled").
    func loadResults() -> [GameResult] {
        guard let data = defaults.data(forKey: storageKey),
              let results = try? JSONDecoder().decode([GameResult].self, from: data) else {
            return []
        }
        return results
    }

    func save(_ result: GameResult) {
        var results = loadResults()
        results.append(result)
        if results.count > Self.maxStoredResults {
            results.removeFirst(results.count - Self.maxStoredResults)
        }
        guard let data = try? JSONEncoder().encode(results) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
