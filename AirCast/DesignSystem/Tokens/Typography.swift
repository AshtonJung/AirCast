import SwiftUI

/// Centralized type scale. All values are built on system text styles so
/// Dynamic Type scaling, bold-text accessibility, and localization keep working.
enum ACFont {
    /// Big hero PM2.5/AQI number on Home. Rounded for a friendlier, less clinical feel.
    static func heroValue() -> Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }

    /// Screen-level titles ("Forecast", "Model Lab").
    static func screenTitle() -> Font {
        .system(.title2, design: .rounded, weight: .bold)
    }

    /// Card / section titles.
    static func cardTitle() -> Font {
        .system(.headline, design: .rounded, weight: .semibold)
    }

    /// Section headers above groups of cards.
    static func sectionHeader() -> Font {
        .system(.subheadline, design: .rounded, weight: .semibold)
    }

    /// Primary body copy.
    static func body() -> Font {
        .system(.body, design: .default, weight: .regular)
    }

    /// Secondary / supporting copy.
    static func caption() -> Font {
        .system(.footnote, design: .default, weight: .regular)
    }

    /// Smallest supporting label (timestamps, provenance, legends).
    static func micro() -> Font {
        .system(.caption2, design: .default, weight: .medium)
    }

    /// Numeric emphasis inside metric pills / chart readouts. Monospaced digits
    /// keep numbers from jittering horizontally as they animate/update.
    static func numericEmphasis() -> Font {
        .system(.title3, design: .rounded, weight: .bold)
    }
}
