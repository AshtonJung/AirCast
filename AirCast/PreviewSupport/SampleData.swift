import Foundation

/// Static, deterministic sample instances for SwiftUI previews. Keeps
/// `#Preview` blocks fast and network-free, and gives every component a
/// realistic, typed data shape to render instead of ad hoc literals scattered
/// across views.
enum SampleData {
    static let now = Date()

    static let observation = AirQualityObservation(
        timestamp: now,
        pm25: 18.4,
        locationName: "Sample City",
        provenance: DataProvenance(source: "AirCast Demo Dataset", kind: .demo, observedOrGeneratedAt: now)
    )

    static let staleObservation = AirQualityObservation(
        timestamp: now.addingTimeInterval(-5 * 3600),
        pm25: 22.1,
        locationName: "Sample City",
        provenance: DataProvenance(source: "AirCast Demo Dataset", kind: .observed, observedOrGeneratedAt: now.addingTimeInterval(-5 * 3600))
    )

    static let forecastPoint = PM25ForecastPoint(
        targetTime: now.addingTimeInterval(24 * 3600),
        pm25: 21.5,
        uncertainty: .computed(lower: 15, upper: 28, coverage: 0.8),
        provenance: DataProvenance(source: "AirCast PM2.5 Forecast Model", kind: .demo, observedOrGeneratedAt: now, modelVersion: "demo-0.1")
    )

    static let driver = ExplanationDriver(
        kind: .windSpeed,
        direction: .decreasesPM25,
        basis: .modelComputed,
        relativeContribution: 0.46,
        explanation: "Sustained onshore wind is associated with lower PM2.5 over the next 24h."
    )

    static let repository = DemoAirQualityRepository()
}
