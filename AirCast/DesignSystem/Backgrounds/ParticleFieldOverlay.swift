import SwiftUI

/// A full-frame field of slowly drifting motes, layered on top of
/// `SmogSkylineView` so the background reads as textured and alive at every
/// scroll position — not just a gradient near the top that settles into a
/// flat haze tone further down. Density scales with `severity`, so it stays
/// data-driven rather than purely decorative.
///
/// Deliberately independent of the 3D scene (a lightweight 2D `Canvas`) so
/// it stays cheap to render behind a long scrolling list.
struct ParticleFieldOverlay: View {
    let tint: Color
    /// 0...1, typically `min(pm25 / 150, 1)`.
    var severity: Double = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var seeds: [SIMD3<Double>] = (0..<90).map { _ in
        SIMD3(Double.random(in: 0...1), Double.random(in: 0...1), Double.random(in: 0...1))
    }

    /// A small palette, not one repeated tint: the AQI color, a warm gold
    /// (matches the sky's horizon color), and the app's cool accent — so the
    /// drifting field reads as a genuine color *combination*.
    private var palette: [Color] {
        [tint, Color(red: 0.97, green: 0.78, blue: 0.45), ACColor.accent]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 24.0, paused: reduceMotion)) { context in
            Canvas { canvasContext, size in
                draw(in: &canvasContext, size: size, date: context.date)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let time = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
        let clampedSeverity = max(0, min(1, severity))
        let activeCount = reduceMotion ? Int(10 + clampedSeverity * 20) : Int(24 + clampedSeverity * 66)

        for index in 0..<min(activeCount, seeds.count) {
            let seed = seeds[index]
            let driftSpeed = 0.01 + seed.x * 0.018
            let yPhase = reduceMotion ? seed.y : (seed.y + time * driftSpeed).truncatingRemainder(dividingBy: 1)
            let sway = reduceMotion ? 0 : sin(time * 0.5 + seed.z * 24) * 0.03
            let x = size.width * min(1, max(0, seed.x + sway))
            let y = size.height * yPhase
            let radius = 1.2 + seed.z * 2.6
            let opacity = 0.08 + seed.y * 0.22
            let color = palette[index % palette.count]

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(opacity))
            )
        }
    }
}

#Preview("ParticleFieldOverlay") {
    ZStack {
        Color.black
        ParticleFieldOverlay(tint: .green, severity: 0.8)
    }
    .ignoresSafeArea()
}
