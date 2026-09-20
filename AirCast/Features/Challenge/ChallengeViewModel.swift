import Foundation
import Observation

/// Drives the Daily Prediction Challenge: today's tactile prediction input
/// (if not yet submitted), the reveal for resolved challenges, and simple
/// accuracy-trend/streak stats — all computed from real submitted data, no
/// invented "gamified" numbers.
@Observable
@MainActor
final class ChallengeViewModel {
    private let repository: AirQualityRepository

    private(set) var phase: LoadPhase = .loading
    private(set) var challenges: [PredictionChallenge] = []
    private(set) var recentObservations: [AirQualityObservation] = []
    var sliderValue: Double = 20
    private(set) var isSubmitting = false
    private(set) var submitErrorMessage: String?
    /// Bumped right after a successful submit so the view can play a single
    /// confirmation animation/haptic without re-triggering on every reload.
    private(set) var submissionTicks: Int = 0

    init(repository: AirQualityRepository) {
        self.repository = repository
    }

    var todayChallenge: PredictionChallenge? {
        challenges.first { Calendar.current.isDateInToday($0.challengeDate) }
    }

    /// Newest resolved challenge first.
    var resolvedChallenges: [PredictionChallenge] {
        challenges.filter(\.isResolved).sorted { $0.challengeDate > $1.challengeDate }
    }

    var averageScore: Double? {
        let scores = resolvedChallenges.compactMap(\.userScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// Consecutive resolved calendar days counting back from the most
    /// recent, with no gap — a simple, honestly-defined streak (not an
    /// arbitrary gamified number).
    var streak: Int {
        let calendar = Calendar.current
        let days = resolvedChallenges.map { calendar.startOfDay(for: $0.challengeDate) }
        guard var cursor = days.first else { return 0 }
        var count = 1
        for day in days.dropFirst() {
            guard let expected = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            if calendar.isDate(day, inSameDayAs: expected) {
                count += 1
                cursor = expected
            } else {
                break
            }
        }
        return count
    }

    func load() async {
        let hadData = !challenges.isEmpty
        if !hadData { phase = .loading }
        do {
            async let challengesTask = repository.predictionChallenges()
            async let observationsTask = repository.recentObservations(limit: 24)
            let (fetchedChallenges, observations) = try await (challengesTask, observationsTask)

            challenges = fetchedChallenges.sorted { $0.challengeDate > $1.challengeDate }
            recentObservations = observations
            if let latest = observations.first, sliderValue == 20 {
                sliderValue = latest.pm25.rounded()
            }
            phase = .loaded
        } catch {
            if !hadData {
                phase = .failed(RepositoryErrorPresentation.kind(for: error), message: RepositoryErrorPresentation.message(for: error))
            }
        }
    }

    func submit() async {
        guard todayChallenge == nil, !isSubmitting else { return }
        isSubmitting = true
        submitErrorMessage = nil
        do {
            let challenge = try await repository.submitPrediction(pm25: sliderValue, for: Date())
            challenges.insert(challenge, at: 0)
            submissionTicks += 1
        } catch {
            submitErrorMessage = Self.submitMessage(for: error)
        }
        isSubmitting = false
    }

    private static func submitMessage(for error: Error) -> String {
        guard let repoError = error as? AirQualityRepositoryError else {
            return "Something went wrong. Please try again."
        }
        switch repoError {
        case .predictionAlreadySubmitted: return "You already have a prediction in for today."
        case .predictionCutoffPassed: return "Today's prediction window has closed."
        default: return RepositoryErrorPresentation.message(for: error)
        }
    }
}
