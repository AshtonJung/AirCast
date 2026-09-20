import SwiftUI
import UIKit

/// Centralized semantic color tokens for AirCast.
///
/// Feature views must never reach for raw `Color(red:green:blue:)` values or
/// system colors directly — always go through `ACColor` so the whole app
/// stays visually coherent and themeable from one place.
enum ACColor {

    // MARK: Surfaces

    /// Base app background. Deep, calm, and lets atmospheric backgrounds read clearly.
    static let background = Color.dynamic(
        light: Color(hex: 0xF4F7F8),
        dark: Color(hex: 0x0B0F14)
    )

    /// Elevated card/sheet surface.
    static let surface = Color.dynamic(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x141A22)
    )

    /// Secondary, slightly recessed surface (nested content, chips).
    static let surfaceSecondary = Color.dynamic(
        light: Color(hex: 0xEDF1F3),
        dark: Color(hex: 0x1C232D)
    )

    /// Hairline separators and card borders.
    static let separator = Color.dynamic(
        light: Color(hex: 0xDCE3E6),
        dark: Color(hex: 0x2A323D)
    )

    // MARK: Text

    static let textPrimary = Color.dynamic(
        light: Color(hex: 0x101418),
        dark: Color(hex: 0xF4F7F8)
    )

    static let textSecondary = Color.dynamic(
        light: Color(hex: 0x475259),
        dark: Color(hex: 0xA9B4BC)
    )

    static let textTertiary = Color.dynamic(
        light: Color(hex: 0x7C8890),
        dark: Color(hex: 0x707B84)
    )

    /// Text/icon color intended to sit on top of a saturated status color (e.g. AQI hero).
    static let textOnStatus = Color.white

    // MARK: Brand / accent

    /// Primary brand accent — used sparingly for CTAs and highlighted state, not for AQI meaning.
    static let accent = Color.dynamic(
        light: Color(hex: 0x1E8FB3),
        dark: Color(hex: 0x59C4E8)
    )

    // MARK: Feedback

    static let positive = Color.dynamic(light: Color(hex: 0x2E9B5B), dark: Color(hex: 0x54C980))
    static let warning = Color.dynamic(light: Color(hex: 0xB8892B), dark: Color(hex: 0xE0AC4D))
    static let danger = Color.dynamic(light: Color(hex: 0xC24444), dark: Color(hex: 0xE2696A))

    // MARK: AQI / PM2.5 status scale
    //
    // These map 1:1 to `AQICategory` in AQIStatus.swift. Kept here (rather than
    // computed ad hoc in views) so every screen — Home hero, Forecast chart,
    // Model Lab diagnostics — renders air-quality severity identically.

    static let aqiGood = Color(hex: 0x3FB56B)
    static let aqiModerate = Color(hex: 0xD9C13B)
    static let aqiUnhealthySensitive = Color(hex: 0xE8933C)
    static let aqiUnhealthy = Color(hex: 0xDE5B4F)
    static let aqiVeryUnhealthy = Color(hex: 0x9A4FB0)
    static let aqiHazardous = Color(hex: 0x7E2436)

    /// Observed-vs-forecast legend colors. Never reuse status colors for this —
    /// the distinction must survive even when AQI category also changes.
    static let observedSeries = Color.dynamic(light: Color(hex: 0x1E293B), dark: Color(hex: 0xE6EBF0))
    static let forecastSeries = accent
    static let uncertaintyBand = accent.opacity(0.18)
}

extension Color {
    /// Builds a `Color` that resolves differently per color scheme, without
    /// requiring an Asset Catalog entry for every token.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
