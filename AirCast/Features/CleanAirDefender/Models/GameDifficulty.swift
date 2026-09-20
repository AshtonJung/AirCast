import Foundation

/// Coarse difficulty bucket for a Clean Air Defender round. Milestone 2 uses
/// a single fixed `.standard` scenario; Milestone 4's `GameScenarioMapper`
/// will pick a case from real forecast context (e.g. a higher forecast PM2.5
/// leaning toward `.hard`). Declared now so `GameScenario`'s shape doesn't
/// need to change later.
enum GameDifficulty: String, CaseIterable, Codable {
    case easy
    case standard
    case hard
}
