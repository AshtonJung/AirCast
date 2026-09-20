import SwiftUI

/// Spacing scale. Prefer these over raw numeric literals in feature views.
enum ACSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner radius scale, tuned for a soft "glass" premium feel without looking bubbly.
enum ACRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let pill: CGFloat = 999
}

/// Elevation tokens expressed as shadow parameters. Kept subtle — depth should
/// come primarily from materials/blur, not heavy drop shadows.
enum ACElevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let card = Shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    static let floating = Shadow(color: .black.opacity(0.20), radius: 28, x: 0, y: 14)
}

extension View {
    /// Applies a standard AirCast card elevation shadow.
    func acShadow(_ shadow: ACElevation.Shadow = ACElevation.card) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
