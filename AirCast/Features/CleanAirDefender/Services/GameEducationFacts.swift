import Foundation

/// Surfaces real educational content that already exists elsewhere in
/// AirCast (`AQICategory.guidance`, the bundled research dataset) but was
/// never shown inside Clean Air Defender — added so a round teaches more
/// than "wind/rain can help," without inventing a single new fact (work
/// order §2: never fabricate).
enum GameEducationFacts {
    /// The real EPA-style health guidance for the round's forecast
    /// category — e.g. "Sensitive groups may experience health effects."
    /// This is the same `AQICategory.guidance` text the app already defines
    /// but, before this, displayed nowhere in the app at all: it answers
    /// "what does this number actually mean for me," which the round's
    /// score/persistence numbers alone don't.
    static func healthGuidance(forecastPM25: Double) -> (category: AQICategory, guidance: String) {
        let category = AQICategory.classify(pm25: forecastPM25)
        return (category, category.guidance)
    }

    /// A single real fact about the dataset behind AirCast's forecast
    /// model, pulled directly from the bundled, machine-checked research
    /// data (`BundledResearchDataTests` verifies these numbers against the
    /// shipped JSON) — never a rounded/invented figure.
    static let datasetFact: String = {
        let dataset = BundledResearchData.forecastModel.dataset
        return "AirCast's forecast model is fitted on \(dataset.nConsecutiveDayPairs) real day-pairs of EPA/NOAA data from \(dataset.geography), \(year(from: dataset.dateRangeStart))–\(year(from: dataset.dateRangeEnd))."
    }()

    private static func year(from isoDate: String) -> String {
        String(isoDate.prefix(4))
    }
}
