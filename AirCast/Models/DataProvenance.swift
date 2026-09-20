import Foundation

/// Where a piece of data came from and how fresh it is. Attached to every
/// observation, forecast, and driver value shown in the UI so no screen can
/// display a number without a traceable source, timestamp, and status.
///
/// This is the backbone of AirCast's data-integrity rule: never silently mix
/// observed and predicted values, and never show a statistic without a path
/// back to where it came from.
struct DataProvenance: Equatable, Codable, Hashable {
    enum Kind: String, Codable {
        /// A measured value from a sensor/station network.
        case observed
        /// A model-produced value (point forecast, interval, driver contribution).
        case predicted
        /// A previously fetched value being reused because a fresh fetch failed.
        case cached
        /// Bundled deterministic sample data, used when there is no live source
        /// (offline demo, CAC judging, previews). Never presented as if it were live.
        case demo
    }

    /// Human-readable source, e.g. "OpenAQ station US-CA-0123", "AirCast PM2.5 model v1.2".
    let source: String
    let kind: Kind
    /// When this value was produced/measured (not when it was fetched into the app).
    let observedOrGeneratedAt: Date
    /// When the app last successfully retrieved this value.
    let retrievedAt: Date
    /// Model/algorithm version string, when `kind == .predicted`. Nil for raw observations.
    let modelVersion: String?

    init(
        source: String,
        kind: Kind,
        observedOrGeneratedAt: Date,
        retrievedAt: Date = Date(),
        modelVersion: String? = nil
    ) {
        self.source = source
        self.kind = kind
        self.observedOrGeneratedAt = observedOrGeneratedAt
        self.retrievedAt = retrievedAt
        self.modelVersion = modelVersion
    }

    /// Whether this value should be flagged "stale" in the UI. Threshold is
    /// intentionally generous (2h) because PM2.5 station updates are typically hourly.
    func isStale(asOf now: Date = Date(), threshold: TimeInterval = 2 * 3600) -> Bool {
        now.timeIntervalSince(observedOrGeneratedAt) > threshold
    }
}
