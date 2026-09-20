import SwiftUI

/// A subtle Wallet-card-style 3D tilt that follows a drag, then springs back.
/// Purely a touch-feedback flourish (rule: motion must still be readable —
/// the tilt range is capped small enough to never obscure card content), and
/// collapses to zero rotation under Reduce Motion while still tracking the
/// gesture so layout doesn't jump.
private struct TiltInteraction: ViewModifier {
    @GestureState private var dragTranslation: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let factor: CGFloat = reduceMotion ? 0 : 1
        content
            .rotation3DEffect(
                .degrees(Double(dragTranslation.height / 14) * factor),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.4
            )
            .rotation3DEffect(
                .degrees(Double(-dragTranslation.width / 14) * factor),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.4
            )
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in
                        state = CGSize(
                            width: max(-40, min(40, value.translation.width)),
                            height: max(-40, min(40, value.translation.height))
                        )
                    }
            )
            .animation(.spring(response: 0.45, dampingFraction: 0.65), value: dragTranslation)
    }
}

extension View {
    /// Applies the shared card-tilt touch interaction. Avoid combining with
    /// a child view that already owns its own drag gesture (e.g. `SmogSkylineView`
    /// or `StationMapCard`'s map) — the two gestures will compete for the same touches.
    func tiltInteractive() -> some View {
        modifier(TiltInteraction())
    }
}
