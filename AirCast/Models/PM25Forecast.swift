import Foundation

/// An uncertainty representation for a forecast point. AirCast never shows a
/// bare point forecast — every predicted value is paired with one of these so
/// the UI can never imply false precision.
struct ForecastUncertainty: Equatable, Codable {
    enum Method: String, Codable {
        /// A statistically computed interval (e.g. from residual quantiles or a
        /// predictive-distribution model). Safe to label with a numeric coverage
        /// (e.g. "80% interval") ONLY when this method is used.
        case computedInterval
        /// A coarse, non-numeric confidence bucket derived from a heuristic
        /// (e.g. data recency/sparsity). Must be labeled qualitatively, never
        /// given a fabricated percentage.
        case qualitativeHeuristic
    }

    let method: Method
    /// Lower/upper bound in µg/m³. Present only when `method == .computedInterval`.
    let lowerBound: Double?
    let upperBound: Double?
    /// Nominal coverage of the interval, e.g. 0.8 for an 80% interval. Present
    /// only when `method == .computedInterval` and the model actually validated it.
    let coverage: Double?
    /// Qualitative confidence bucket, used when `method == .qualitativeHeuristic`.
    let qualitativeLevel: QualitativeLevel?

    enum QualitativeLevel: String, Codable, CaseIterable {
        case high, medium, low

        var label: String {
            switch self {
            case .high: return "High confidence"
            case .medium: return "Medium confidence"
            case .low: return "Lower confidence"
            }
        }
    }

    static func computed(lower: Double, upper: Double, coverage: Double) -> ForecastUncertainty {
        ForecastUncertainty(method: .computedInterval, lowerBound: lower, upperBound: upper, coverage: coverage, qualitativeLevel: nil)
    }

    static func qualitative(_ level: QualitativeLevel) -> ForecastUncertainty {
        ForecastUncertainty(method: .qualitativeHeuristic, lowerBound: nil, upperBound: nil, coverage: nil, qualitativeLevel: level)
    }
}

/// One point on the forecast horizon (hourly or daily).
struct PM25ForecastPoint: Identifiable, Equatable, Codable {
    var id: Date { targetTime }
    let targetTime: Date
    /// Point (central) forecast in µg/m³.
    let pm25: Double
    let uncertainty: ForecastUncertainty
    let provenance: DataProvenance

    var category: AQICategory { AQICategory.classify(pm25: pm25) }
}

/// A full forecast horizon (e.g. next 24-72h), plus the drivers that explain it.
struct PM25Forecast: Equatable, Codable {
    let generatedAt: Date
    let points: [PM25ForecastPoint]
    let drivers: [ExplanationDriver]
    let modelVersion: String

    /// Forecast for a specific calendar day, if present.
    func point(closestTo date: Date) -> PM25ForecastPoint? {
        points.min { lhs, rhs in
            abs(lhs.targetTime.timeIntervalSince(date)) < abs(rhs.targetTime.timeIntervalSince(date))
        }
    }
}
