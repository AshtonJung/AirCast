import Foundation

/// A single verified evaluation metric (MAE, RMSE, etc). Every number shown
/// in Model Lab must come from one of these — never a hard-coded UI string.
struct EvaluationMetric: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    /// Plain-language definition shown on tap/expand.
    let definition: String
    let value: Double
    let unit: String
    /// Same metric computed for a naive/persistence baseline, for honest comparison.
    let baselineValue: Double?

    init(id: UUID = UUID(), name: String, definition: String, value: Double, unit: String, baselineValue: Double? = nil) {
        self.id = id
        self.name = name
        self.definition = definition
        self.value = value
        self.unit = unit
        self.baselineValue = baselineValue
    }
}

/// Describes the dataset backing the model — required so a statistics-minded
/// reviewer can judge validity, not just take AirCast's word for it.
struct DatasetCard: Equatable, Codable {
    let sourceName: String
    let geography: String
    let dateRangeDescription: String
    /// Verified sample size, if known. Never display an invented count.
    let sampleSize: Int?
    let variables: [String]
    let lastUpdated: Date
}

/// Describes the forecasting model itself.
struct ModelDescription: Equatable, Codable {
    let modelType: String
    let target: String
    let inputs: [String]
    let version: String
    let trainingValidationApproach: String
    let deploymentStatus: String
}

/// A separate, deeper research result that motivates the app but is **not**
/// itself the forecasting model — e.g. a published/submitted statistical
/// study establishing *why* certain features (wind, precipitation) matter.
/// Kept distinct from `ModelDescription` so AirCast never implies its simple
/// on-device forecast regression *is* the peer-reviewed study, while still
/// giving judges the real research narrative.
struct RelatedResearch: Equatable, Codable {
    let title: String
    /// One-paragraph, plain-language summary of what was studied and found.
    let summary: String
    /// The single headline statistic, stated exactly as computed (e.g. a
    /// hazard ratio with its confidence interval and p-value). Never rounded
    /// away from its reported precision or stripped of its interval.
    let keyFinding: String
    let methodology: String
    let limitations: [String]
}

/// The single source of truth for everything AirCast claims about its model.
/// Model Lab, the Why screen, and Home's "confidence" language should all
/// ultimately read from a `ModelCard` instance rather than restating claims.
struct ModelCard: Equatable, Codable {
    let researchQuestion: String
    let dataset: DatasetCard
    let model: ModelDescription
    let metrics: [EvaluationMetric]
    let limitations: [String]
    let responsibleUseStatement: String
    /// The deeper statistical study (survival/hazard analysis of PM2.5
    /// episode recovery) that motivates which features the forecast model
    /// uses. Optional because not every build will have an associated study.
    let relatedResearch: RelatedResearch?
}
