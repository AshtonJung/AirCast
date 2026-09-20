import SwiftUI

/// Centralized motion tokens. AirCast's rule is: animation must communicate
/// state (data changing, selection moving, refresh happening) — never pure
/// decoration. Every spring/duration used across the app should trace back here.
enum ACMotion {
    /// Snappy UI feedback: button press, tab switch, toggle.
    static let quickSpring = Animation.spring(response: 0.32, dampingFraction: 0.86)

    /// Standard content transition: card appear, value update, chart selection.
    static let standardSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)

    /// Large, slow movement: hero atmosphere drift, onboarding transitions.
    static let ambientSpring = Animation.spring(response: 0.9, dampingFraction: 0.9)

    /// Pull-to-refresh / reveal moments that should feel a little celebratory.
    static let expressiveSpring = Animation.spring(response: 0.55, dampingFraction: 0.68)

    static let quickDuration: Double = 0.2
    static let standardDuration: Double = 0.35
}

extension View {
    /// Animates `value` using an AirCast motion token, automatically respecting
    /// Reduce Motion by falling back to a quick, calm cross-fade.
    func acAnimation<V: Equatable>(_ animation: Animation = ACMotion.standardSpring, value: V) -> some View {
        modifier(ACAnimationModifier(animation: animation, value: value))
    }
}

private struct ACAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: ACMotion.quickDuration) : animation, value: value)
    }
}
