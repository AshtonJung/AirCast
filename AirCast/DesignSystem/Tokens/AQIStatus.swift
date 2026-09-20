import SwiftUI

/// US EPA PM2.5 AQI category breakpoints (24-hour PM2.5, µg/m³ → AQI).
/// Source: US EPA "Technical Assistance Document for the Reporting of Daily
/// Air Quality" (AQI breakpoints table). Used for classification and color
/// only — AirCast does not recompute the full AQI formula, it reports PM2.5
/// concentration directly and uses these breakpoints purely for status/color.
enum AQICategory: Int, CaseIterable, Identifiable, Codable {
    case good
    case moderate
    case unhealthyForSensitiveGroups
    case unhealthy
    case veryUnhealthy
    case hazardous

    var id: Int { rawValue }

    /// Normalizes a PM2.5 concentration to 0...1 for visual intensity
    /// purposes only (particle density, glow strength) — never shown as a
    /// number. 150 µg/m³ (the "Unhealthy" ceiling) maps to 1.0.
    static func normalizedSeverity(pm25 concentration: Double) -> Double {
        max(0, min(1, concentration / 150))
    }

    /// Classifies a PM2.5 concentration in µg/m³ into an EPA AQI category.
    static func classify(pm25 concentration: Double) -> AQICategory {
        switch concentration {
        case ..<12.1: return .good
        case ..<35.5: return .moderate
        case ..<55.5: return .unhealthyForSensitiveGroups
        case ..<150.5: return .unhealthy
        case ..<250.5: return .veryUnhealthy
        default: return .hazardous
        }
    }

    var label: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .unhealthyForSensitiveGroups: return "Unhealthy for Sensitive Groups"
        case .unhealthy: return "Unhealthy"
        case .veryUnhealthy: return "Very Unhealthy"
        case .hazardous: return "Hazardous"
        }
    }

    /// Short label for compact UI (pills, chart legend).
    var shortLabel: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .unhealthyForSensitiveGroups: return "USG"
        case .unhealthy: return "Unhealthy"
        case .veryUnhealthy: return "Very Unhealthy"
        case .hazardous: return "Hazardous"
        }
    }

    var color: Color {
        switch self {
        case .good: return ACColor.aqiGood
        case .moderate: return ACColor.aqiModerate
        case .unhealthyForSensitiveGroups: return ACColor.aqiUnhealthySensitive
        case .unhealthy: return ACColor.aqiUnhealthy
        case .veryUnhealthy: return ACColor.aqiVeryUnhealthy
        case .hazardous: return ACColor.aqiHazardous
        }
    }

    /// SF Symbol used as a non-color status cue (accessibility requirement:
    /// status must never be conveyed by color alone).
    var symbolName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .unhealthyForSensitiveGroups: return "exclamationmark.triangle.fill"
        case .unhealthy: return "exclamationmark.triangle.fill"
        case .veryUnhealthy: return "xmark.octagon.fill"
        case .hazardous: return "xmark.octagon.fill"
        }
    }

    /// Plain-language guidance. Kept factual and non-alarmist; not medical advice.
    var guidance: String {
        switch self {
        case .good:
            return "Air quality is satisfactory for everyone."
        case .moderate:
            return "Acceptable air quality. Unusually sensitive individuals should consider limiting prolonged outdoor exertion."
        case .unhealthyForSensitiveGroups:
            return "Sensitive groups may experience health effects. General public is less likely to be affected."
        case .unhealthy:
            return "Everyone may begin to experience health effects; sensitive groups may experience more serious effects."
        case .veryUnhealthy:
            return "Health alert: everyone may experience more serious health effects."
        case .hazardous:
            return "Health warning of emergency conditions. The entire population is more likely to be affected."
        }
    }
}
