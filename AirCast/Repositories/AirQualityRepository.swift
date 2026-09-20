import Foundation

/// Everything a feature view needs about current + forecast air quality for
/// one location. Views must always go through a repository conforming to
/// this protocol — never decode network/bundle data directly in a View.
protocol AirQualityRepository {
    /// Most recent observation(s), most recent first.
    func recentObservations(limit: Int) async throws -> [AirQualityObservation]
    func latestObservation() async throws -> AirQualityObservation
    func forecast() async throws -> PM25Forecast
    func modelCard() async throws -> ModelCard

    // Prediction Challenge
    func predictionChallenges() async throws -> [PredictionChallenge]
    func submitPrediction(pm25: Double, for date: Date) async throws -> PredictionChallenge
}

/// Errors a repository can surface. Feature view models translate these into
/// the shared loading/empty/error/offline state components — never into an
/// ad hoc string thrown together in the view.
enum AirQualityRepositoryError: Error, Equatable {
    case network
    case noData
    case staleBeyondThreshold
    case decoding
    case predictionCutoffPassed
    case predictionAlreadySubmitted
}
