import SwiftUI

/// Score / timer / combo readout overlaid on the SpriteKit scene.
///
/// Deliberately plain SwiftUI text over the scene rather than SpriteKit
/// labels, so Dynamic Type, VoiceOver, and AirCast's existing `ACFont`/
/// `ACColor` tokens keep working without extra plumbing inside the scene
/// (work order §16, §18).
struct GameHUDView: View {
    let score: Int
    let combo: Int
    let timeRemaining: TimeInterval
    /// 0 (clear) ... 1 (fully hazy) — the same value driving the haze tint
    /// and the live `SmogSkylineView` backdrop, surfaced here as a plain
    /// legible percentage so "you are clearing the air" isn't only an
    /// ambient visual effect but a number the player can point to.
    let hazeLevel: Double
    /// The round's real forecast PM2.5, if one loaded — kept visible for the
    /// entire round (not just the entry/result screens) so the link between
    /// "the game I'm playing" and "AirCast's actual forecast" stays legible
    /// throughout play, addressing that the connection previously only
    /// showed up at the bookends of the flow.
    let forecastPM25: Double?
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: ACSpacing.xxs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(score)")
                        .font(ACFont.numericEmphasis())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .accessibilityLabel("Score \(score)")
                    if combo >= 2 {
                        Text("Combo x\(combo)")
                            .font(ACFont.micro())
                            .foregroundStyle(ACColor.aqiModerate)
                            .accessibilityLabel("Combo times \(combo)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(timeString)
                    .font(ACFont.numericEmphasis())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .accessibilityLabel("\(max(0, Int(timeRemaining.rounded()))) seconds remaining")
                    .frame(maxWidth: .infinity)

                Button(action: onPause) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("Pause")
            }

            connectionRow
        }
        .padding(.horizontal, ACSpacing.md)
        .padding(.top, ACSpacing.sm)
    }

    /// A persistent, always-visible strip tying this specific round to
    /// AirCast's forecast — and, critically, using the model's own
    /// vocabulary. "Persistence" is `hazeLevel` shown directly (not
    /// inverted into a made-up "Clarity" score): it's literally how much of
    /// today's PM2.5 is still un-removed, the same concept named in the
    /// round-opening callout and in `GameScienceRecap`. A viewer watching
    /// this drop as clusters get cleared is watching "persistence vs.
    /// removal" play out, not an arbitrary game meter.
    private var connectionRow: some View {
        HStack(spacing: ACSpacing.xs) {
            if let forecastPM25 {
                Label("\(Int(forecastPM25.rounded())) µg/m³ forecast", systemImage: "cloud.sun.fill")
            }
            Text("Persistence \(persistencePercent)%")
                .contentTransition(.numericText())
        }
        .font(ACFont.micro())
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, ACSpacing.sm)
        .padding(.vertical, 4)
        .background(.black.opacity(0.28), in: Capsule())
        .animation(.easeOut(duration: 0.3), value: persistencePercent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(connectionAccessibilityLabel)
    }

    private var persistencePercent: Int {
        Int((hazeLevel * 100).rounded())
    }

    private var connectionAccessibilityLabel: String {
        var parts: [String] = []
        if let forecastPM25 {
            parts.append("AirCast forecast \(Int(forecastPM25.rounded())) micrograms per cubic meter")
        }
        parts.append("PM2.5 persistence \(persistencePercent) percent")
        return parts.joined(separator: ". ")
    }

    private var timeString: String {
        let seconds = max(0, Int(timeRemaining.rounded()))
        return "0:\(String(format: "%02d", seconds))"
    }
}

#Preview("Game HUD") {
    ZStack {
        Color.black
        VStack {
            GameHUDView(score: 620, combo: 3, timeRemaining: 27, hazeLevel: 0.4, forecastPM25: 34, onPause: {})
            Spacer()
        }
    }
}
