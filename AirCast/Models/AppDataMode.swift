import Foundation

/// Which data mode the app is currently operating in. Surfaced in Settings
/// (dev/demo builds) and used to pick a repository implementation.
enum AppDataMode: String, CaseIterable, Codable {
    /// Bundled, deterministic, visually rich scenarios. No network required.
    /// This is the default and the guaranteed-reliable CAC demo path.
    case demo
    /// Real data integration.
    case live
    /// Last validated live result, served because a fresh live fetch failed.
    case cachedOffline
}

/// A named, deterministic demo scenario (rule: "curated scenarios, selectable
/// through a development/demo mechanism"). Fleshed out fully in the Data &
/// Forecast Engine milestone; declared here so the shell/UI can already
/// reason about "which scenario am I previewing."
enum DemoScenario: String, CaseIterable, Identifiable, Codable {
    case cleanAirImproving
    case moderateRising
    case unhealthyLowConfidence
    case staleOffline
    case challengeRevealReady

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cleanAirImproving: return "Clean air, improving"
        case .moderateRising: return "Moderate, rising"
        case .unhealthyLowConfidence: return "Unhealthy episode, lower confidence"
        case .staleOffline: return "Stale / offline"
        case .challengeRevealReady: return "Prediction Challenge reveal"
        }
    }
}
