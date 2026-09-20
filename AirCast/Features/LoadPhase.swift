import Foundation

/// Shared loading/loaded/failed state for feature view models. Kept generic
/// (not Home- or Forecast-specific) so every screen renders the same
/// skeleton/error/empty vocabulary from `ACStateView` instead of each
/// reinventing its own loading enum.
enum LoadPhase: Equatable {
    case loading
    case loaded
    case failed(ACStateView.Kind, message: String)
}

/// Maps a thrown `AirQualityRepositoryError` to the state-view kind and
/// human-readable message every feature view model should show. Centralized
/// so Home, Forecast, and future screens present the same error identically.
enum RepositoryErrorPresentation {
    static func kind(for error: Error) -> ACStateView.Kind {
        guard let repoError = error as? AirQualityRepositoryError else { return .error }
        switch repoError {
        case .network: return .offline
        case .staleBeyondThreshold: return .stale
        case .noData, .decoding, .predictionCutoffPassed, .predictionAlreadySubmitted: return .error
        }
    }

    static func message(for error: Error) -> String {
        guard let repoError = error as? AirQualityRepositoryError else {
            return "Something went wrong while loading AirCast."
        }
        switch repoError {
        case .network: return "Couldn't reach the network. Showing what we can from the last saved data."
        case .noData: return "No data is available right now."
        case .staleBeyondThreshold: return "The last saved data is too old to show reliably."
        case .decoding: return "Something went wrong reading the latest data."
        case .predictionCutoffPassed, .predictionAlreadySubmitted: return "Something went wrong."
        }
    }
}
