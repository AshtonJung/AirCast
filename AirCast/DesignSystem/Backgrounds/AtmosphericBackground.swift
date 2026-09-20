import SwiftUI

/// A full-bleed, slowly-drifting gradient field driven by air-quality state,
/// with an ambient field of drifting motes whose *density* follows
/// `severity` — worse air visibly means a busier, hazier sky, not just a
/// different tint. This is the single reusable "the app feels alive"
/// surface — Home, Forecast, and Why all sit on top of one rather than each
/// inventing their own animated background.
///
/// Motion is intentionally slow and diffuse (never distracting from data) and
/// collapses to a calm, mostly-static field when Reduce Motion is on.
struct AtmosphericBackground: View {
    let category: AQICategory
    /// 0...1, typically `min(pm25 / 150, 1)`. Defaults to a gentle mid-level
    /// so screens that don't yet have a live reading still look intentional.
    var severity: Double = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moteSeeds: [SIMD2<Double>] = (0..<64).map { _ in SIMD2(Double.random(in: 0...1), Double.random(in: 0...1)) }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0, paused: reduceMotion)) { context in
            Canvas { canvasContext, size in
                draw(in: &canvasContext, size: size, date: context.date)
            }
        }
        .background(ACColor.background)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let time = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
        let slowPhase = reduceMotion ? 0 : sin(time / 9.0) * 0.5 + 0.5

        let topColor = category.color.opacity(0.55)
        let bottomColor = ACColor.background

        let gradient = Gradient(colors: [topColor, bottomColor])
        let centerX = size.width * (0.3 + 0.4 * slowPhase)
        let centerY = size.height * 0.15

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: centerX, y: centerY),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.9
            )
        )

        // Secondary, subtler drifting glow for depth.
        let secondaryPhase = reduceMotion ? 0.5 : cos(time / 13.0) * 0.5 + 0.5
        context.opacity = 0.35
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [category.color.opacity(0.4), .clear]),
                center: CGPoint(x: size.width * (0.6 + 0.3 * secondaryPhase), y: size.height * 0.6),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.6
            )
        )

        // Third, slowest layer — a wide, faint counter-drifting glow that
        // gives the whole field a sense of parallax depth rather than one
        // flat gradient. Barely visible on its own, but the layering reads.
        let tertiaryPhase = reduceMotion ? 0.5 : sin(time / 21.0 + 2.0) * 0.5 + 0.5
        context.opacity = 0.22
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [category.color.opacity(0.5), .clear]),
                center: CGPoint(x: size.width * (0.15 + 0.5 * tertiaryPhase), y: size.height * 0.85),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.55
            )
        )

        drawMotes(in: &context, size: size, time: time)

        // A thin top sheen, like light catching glass, anchors the premium
        // "glass over atmosphere" material feel used across the app's cards.
        context.opacity = 1
        context.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.4)),
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.06), .clear]),
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height * 0.4)
            )
        )
    }

    /// Ambient drifting motes. Count scales with `severity` — this is the
    /// background's data-driven "wow," not decoration: a hazardous scenario
    /// visibly fills the sky, a good-air scenario barely shows any.
    private func drawMotes(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let clampedSeverity = max(0, min(1, severity))
        let activeCount = reduceMotion ? Int(4 + clampedSeverity * 10) : Int(8 + clampedSeverity * 56)

        for index in 0..<min(activeCount, moteSeeds.count) {
            let seed = moteSeeds[index]
            let driftSpeed = 0.012 + seed.x * 0.02
            let yPhase = reduceMotion ? seed.y : (seed.y + time * driftSpeed).truncatingRemainder(dividingBy: 1)
            let sway = reduceMotion ? 0 : sin(time * 0.6 + seed.x * 20) * 0.02
            let x = size.width * min(1, max(0, seed.x + sway))
            let y = size.height * (1 - yPhase)
            let radius = 1.5 + seed.y * 2.5
            let opacity = 0.15 + seed.x * 0.35

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(category.color.opacity(opacity))
            )
        }
    }
}

#Preview("Atmospheric — Good") {
    AtmosphericBackground(category: .good, severity: 0.08)
}

#Preview("Atmospheric — Hazardous") {
    AtmosphericBackground(category: .hazardous, severity: 0.95)
}
