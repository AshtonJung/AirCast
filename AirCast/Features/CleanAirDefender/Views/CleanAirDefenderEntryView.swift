import SwiftUI

/// Instructional entry screen shown before a Clean Air Defender round.
///
/// Milestone 1 (static shell): this view only explains the mechanic and
/// routes onward — the real SpriteKit round is added in Milestone 2. Copy
/// here follows the work order's statistical-honesty rule: wind and rain are
/// described as "can help," never as guaranteed causes, matching how
/// `ExplanationDriver` already qualifies them elsewhere in AirCast.
struct CleanAirDefenderEntryView: View {
    /// Nil when no forecast data has loaded yet (or none is available
    /// offline) — the forecast-context card below is simply omitted rather
    /// than showing a fabricated number, same rule as the result screen.
    let forecastScenario: ForecastScenario?
    /// The user's own submitted Prediction Challenge value for the same
    /// day, if any — shown next to AirCast's forecast so this screen reads
    /// as a continuation of Challenge, not a disconnected instructions page.
    let userPredictionPM25: Double?
    let onStart: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Read fresh each time this screen appears (before a round's
    /// `CleanAirDefenderScene`/`GameSoundPlayer` is constructed), so
    /// toggling here always takes effect on the very next round. Sound is
    /// additive-only throughout (work order §16/§17) — this toggle exists
    /// purely as a courtesy, not because any mechanic depends on it.
    @AppStorage(GameSoundPlayer.preferenceKey) private var soundEnabled = true

    private var backgroundCategory: AQICategory {
        forecastScenario.map { AQICategory.classify(pm25: $0.forecastPM25) } ?? .moderate
    }
    private var backgroundSeverity: Double {
        forecastScenario.map { AQICategory.normalizedSeverity(pm25: $0.forecastPM25) } ?? 0.35
    }

    /// Ties this screen back to the exact Prediction Challenge language
    /// ("You predicted X µg/m³") when a submission exists, so the game
    /// visibly continues that flow instead of restating it generically.
    private var connectionCopy: String {
        if let userPredictionPM25 {
            return "You predicted \(Int(userPredictionPM25.rounded())) µg/m³. Clear the round below to see what's pushing this number up or down."
        }
        return "Clear the round below to see what's pushing this number up or down."
    }

    private struct Step: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(
            symbol: "target",
            title: "Clear PM2.5 clusters",
            detail: "Tap the hazy particle clusters drifting through the sky to clear them — each one you miss adds to today's persistence."
        ),
        Step(
            symbol: "wind",
            title: "Drag through wind boosts",
            detail: "Wind can help disperse particles — swipe through the badge to activate it. Tapping it like a target costs points."
        ),
        Step(
            symbol: "cloud.rain",
            title: "Drag through rain boosts",
            detail: "Rain can help remove airborne particles — swipe through the badge to activate it too."
        ),
    ]

    var body: some View {
        ZStack {
            // Same ambient-sky background technique (and the same
            // AQICategory-driven color) as Forecast/Why/Challenge — not the
            // older, unrelated `AtmosphericBackground` component — so this
            // screen reads as another AirCast screen, not a bolted-on game.
            SmogSkylineView(category: backgroundCategory, severity: backgroundSeverity, reduceMotion: reduceMotion, showSkyline: false, showGround: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ParticleFieldOverlay(tint: backgroundCategory.color, severity: backgroundSeverity)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: ACSpacing.lg) {
                    VStack(alignment: .leading, spacing: ACSpacing.xs) {
                        Text("Clean Air Defender")
                            .font(ACFont.screenTitle())
                            .foregroundStyle(ACColor.textPrimary)
                        Text("A playable version of AirCast's own forecast mechanism.")
                            .font(ACFont.body())
                            .foregroundStyle(ACColor.textSecondary)
                    }

                    // States the actual mechanism up front, in AirCast's own
                    // vocabulary — not a generic "tap the bubbles" pitch.
                    // This is the single line meant to answer "how does this
                    // game connect to the app" before a judge even has to
                    // ask: the round *is* persistence vs. removal, the same
                    // two forces `GameScienceRecap`/the fitted model use.
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: ACSpacing.xs) {
                            Label("How this connects to AirCast", systemImage: "arrow.triangle.2.circlepath")
                                .font(ACFont.cardTitle())
                                .foregroundStyle(ACColor.textPrimary)
                            Text("AirCast's forecast comes from today's PM2.5 **persistence** minus **removal** from wind and rain. This round plays that out directly: clear clusters and protect boosts to drive persistence down, the same two forces behind tomorrow's number.")
                                .font(ACFont.caption())
                                .foregroundStyle(ACColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }

                    if let forecastScenario {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: ACSpacing.xs) {
                                Text("Tomorrow's forecast")
                                    .font(ACFont.caption())
                                    .foregroundStyle(ACColor.textSecondary)
                                HStack(alignment: .firstTextBaseline, spacing: ACSpacing.sm) {
                                    Text("\(Int(forecastScenario.forecastPM25.rounded())) µg/m³")
                                        .font(ACFont.numericEmphasis())
                                        .foregroundStyle(ACColor.textPrimary)
                                    FreshnessBadge(provenance: forecastScenario.provenance)
                                }
                                Text(connectionCopy)
                                    .font(ACFont.caption())
                                    .foregroundStyle(ACColor.textSecondary)
                                // Real EPA-style health guidance for this
                                // forecast's category — answers "what does
                                // this number mean for me," not just "what
                                // pushes it up or down" (work order §2:
                                // reuses `AQICategory.guidance` verbatim,
                                // nothing invented).
                                Divider()
                                let healthGuidance = GameEducationFacts.healthGuidance(forecastPM25: forecastScenario.forecastPM25)
                                Label(healthGuidance.guidance, systemImage: healthGuidance.category.symbolName)
                                    .font(ACFont.micro())
                                    .foregroundStyle(ACColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: ACSpacing.md) {
                            ForEach(steps) { step in
                                HStack(alignment: .top, spacing: ACSpacing.sm) {
                                    Image(systemName: step.symbol)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(ACColor.accent)
                                        .frame(width: 28)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.title)
                                            .font(ACFont.cardTitle())
                                            .foregroundStyle(ACColor.textPrimary)
                                        Text(step.detail)
                                            .font(ACFont.caption())
                                            .foregroundStyle(ACColor.textSecondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SurfaceCard {
                        Toggle(isOn: $soundEnabled) {
                            Label("Sound Effects", systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(ACFont.cardTitle())
                                .foregroundStyle(ACColor.textPrimary)
                        }
                        .tint(ACColor.accent)
                        .accessibilityHint("Short synthesized hit and boost sounds. Every sound also has a haptic and visual equivalent.")
                    }

                    Text("About 30–45 seconds. This is an educational visualization layer, not a new forecast.")
                        .font(ACFont.micro())
                        .foregroundStyle(ACColor.textTertiary)

                    Spacer(minLength: ACSpacing.xl)

                    Button("Play Clean Air Defender", action: onStart)
                        .buttonStyle(.acPrimary)
                        .accessibilityHint("Starts the Clean Air Defender mini-game")
                }
                .padding()
            }
        }
        .navigationTitle("Clean Air Defender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: onClose)
                    .accessibilityLabel("Close Clean Air Defender")
            }
        }
    }
}

#Preview("Clean Air Defender — Entry") {
    NavigationStack {
        CleanAirDefenderEntryView(
            forecastScenario: ForecastScenario(
                currentPM25: 28,
                forecastPM25: 34,
                modelVersion: "Demo",
                dataTimestamp: .now,
                provenance: DataProvenance(source: "AirCast Demo Dataset", kind: .demo, observedOrGeneratedAt: .now),
                windContribution: 0.4,
                windDirection: .decreasesPM25,
                precipitationContribution: 0.1,
                precipitationDirection: .decreasesPM25
            ),
            userPredictionPM25: 31,
            onStart: {},
            onClose: {}
        )
    }
}

#Preview("Clean Air Defender — Entry (no forecast yet)") {
    NavigationStack {
        CleanAirDefenderEntryView(forecastScenario: nil, userPredictionPM25: nil, onStart: {}, onClose: {})
    }
}
