import Foundation

/// A user's daily PM2.5 prediction and its later resolution against the
/// AirCast model forecast and the real observation.
struct PredictionChallenge: Identifiable, Equatable, Codable {
    /// One row per calendar date (in the challenge's recorded time zone).
    let id: UUID
    let challengeDate: Date
    let timeZoneIdentifier: String
    let userPredictionPM25: Double
    let submittedAt: Date
    let cutoffAt: Date
    let modelForecastPM25: Double?
    let observedPM25: Double?
    let resolvedAt: Date?

    init(
        id: UUID = UUID(),
        challengeDate: Date,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        userPredictionPM25: Double,
        submittedAt: Date = Date(),
        cutoffAt: Date,
        modelForecastPM25: Double? = nil,
        observedPM25: Double? = nil,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.challengeDate = challengeDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.userPredictionPM25 = userPredictionPM25
        self.submittedAt = submittedAt
        self.cutoffAt = cutoffAt
        self.modelForecastPM25 = modelForecastPM25
        self.observedPM25 = observedPM25
        self.resolvedAt = resolvedAt
    }

    var isResolved: Bool { observedPM25 != nil }
    var canEdit: Bool { Date() < cutoffAt && !isResolved }

    var userAbsoluteError: Double? {
        guard let observed = observedPM25 else { return nil }
        return abs(userPredictionPM25 - observed)
    }

    var modelAbsoluteError: Double? {
        guard let observed = observedPM25, let model = modelForecastPM25 else { return nil }
        return abs(model - observed)
    }

    /// Continuous accuracy score in [0, 100]. Documented formula (see
    /// `PredictionScoring`): decays smoothly with absolute error rather than
    /// an all-or-nothing threshold, so near-misses are still rewarded.
    var userScore: Double? {
        guard let error = userAbsoluteError else { return nil }
        return PredictionScoring.score(absoluteError: error)
    }
}

/// The exact, documented scoring function used across AirCast (Challenge
/// reveal, Profile accuracy trend). Kept in one place so it is testable and
/// never silently duplicated/diverged between screens.
enum PredictionScoring {
    /// score = 100 * exp(-|error| / decayConstant), floored at 0.
    ///
    /// `decayConstant` (µg/m³) controls how quickly the score falls off with
    /// error; 15 µg/m³ means an error of ~10 still scores ~51, while an error
    /// of ~40 scores ~8. This rewards calibrated closeness over lucky exact
    /// guesses, and never returns a hard zero for a merely-imperfect guess.
    static let decayConstant: Double = 15.0

    static func score(absoluteError: Double) -> Double {
        guard absoluteError.isFinite, absoluteError >= 0 else { return 0 }
        let raw = 100 * exp(-absoluteError / decayConstant)
        return max(0, min(100, raw))
    }
}
