import Foundation

/// One factor contributing to a forecast, shown in the "Why?" strip and the
/// Why explainability screen. AirCast only ever describes these as
/// associations/contributions — never as proven causes.
struct ExplanationDriver: Identifiable, Equatable, Codable {
    enum Kind: String, Codable, CaseIterable {
        case recentPersistence
        case windSpeed
        case windDirection
        case precipitation
        case humidity
        case other

        var label: String {
            switch self {
            case .recentPersistence: return "Recent PM2.5 levels"
            case .windSpeed: return "Wind speed"
            case .windDirection: return "Wind direction"
            case .precipitation: return "Precipitation"
            case .humidity: return "Humidity"
            case .other: return "Other factor"
            }
        }

        var symbolName: String {
            switch self {
            case .recentPersistence: return "clock.arrow.circlepath"
            case .windSpeed: return "wind"
            case .windDirection: return "location.north.line"
            case .precipitation: return "cloud.rain"
            case .humidity: return "humidity"
            case .other: return "questionmark.circle"
            }
        }
    }

    enum Direction: String, Codable {
        case increasesPM25
        case decreasesPM25
        case mixed

        var label: String {
            switch self {
            case .increasesPM25: return "Pushing PM2.5 higher"
            case .decreasesPM25: return "Pushing PM2.5 lower"
            case .mixed: return "Mixed / unclear direction"
            }
        }

        var symbolName: String {
            switch self {
            case .increasesPM25: return "arrow.up.right"
            case .decreasesPM25: return "arrow.down.right"
            case .mixed: return "arrow.left.arrow.right"
            }
        }
    }

    /// How this driver's strength was determined.
    enum Basis: String, Codable {
        /// A numeric contribution/importance from the actual model (e.g. a
        /// regression coefficient or feature-importance score).
        case modelComputed
        /// A simple, transparent rule of thumb, not derived from the trained
        /// model. Must be labeled "rule-based" wherever shown.
        case ruleBased
    }

    let id: UUID
    let kind: Kind
    let direction: Direction
    let basis: Basis
    /// Relative contribution/importance in [0, 1], only meaningful when
    /// `basis == .modelComputed`. Never fabricated when nil.
    let relativeContribution: Double?
    /// One-sentence, plain-language explanation of this specific driver.
    let explanation: String

    init(
        id: UUID = UUID(),
        kind: Kind,
        direction: Direction,
        basis: Basis,
        relativeContribution: Double? = nil,
        explanation: String
    ) {
        self.id = id
        self.kind = kind
        self.direction = direction
        self.basis = basis
        self.relativeContribution = relativeContribution
        self.explanation = explanation
    }
}
