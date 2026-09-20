import SwiftUI

/// Round-result screen for Clean Air Defender: score/stats, a short honest
/// science recap (work order §19), and — when a real forecast loaded — the
/// same "AirCast forecast: X µg/m³" comparison shown elsewhere in the app,
/// so the round visibly connects back to the forecast it was generated from.
struct CleanAirDefenderResultView: View {
    let result: GameResult
    /// Nil when no forecast data was available for this round (offline with
    /// nothing cached, or the round was played before the load finished) —
    /// the forecast comparison and science recap are simply omitted rather
    /// than showing a fabricated number (work order §19).
    let forecastScenario: ForecastScenario?
    let onPlayAgain: () -> Void
    let onBackToForecast: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var recap: [String] {
        GameScienceRecap.takeaways(for: forecastScenario, result: result)
    }

    // Same real forecast category the round's difficulty and entry screen
    // used — not a fixed "good/green" background regardless of the actual
    // forecast, so a genuinely unhealthy forecast doesn't visually read as
    // clean air just because the round is over.
    private var backgroundCategory: AQICategory {
        forecastScenario.map { AQICategory.classify(pm25: $0.forecastPM25) } ?? .moderate
    }
    private var backgroundSeverity: Double {
        forecastScenario.map { AQICategory.normalizedSeverity(pm25: $0.forecastPM25) } ?? 0.35
    }

    var body: some View {
        ZStack {
            SmogSkylineView(category: backgroundCategory, severity: backgroundSeverity, reduceMotion: reduceMotion, showSkyline: false, showGround: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ParticleFieldOverlay(tint: backgroundCategory.color, severity: backgroundSeverity)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: ACSpacing.lg) {
                    VStack(spacing: ACSpacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(ACColor.positive)
                            .accessibilityHidden(true)
                        Text("\(result.score) pts")
                            .font(ACFont.heroValue())
                            .foregroundStyle(ACColor.textPrimary)
                            .accessibilityLabel("Score \(result.score) points")
                    }
                    .padding(.top, ACSpacing.lg)

                    SurfaceCard {
                        VStack(spacing: ACSpacing.sm) {
                            resultRow(label: "Particle clusters cleared", value: "\(result.particlesCleared)")
                            resultRow(label: "High-density clusters", value: "\(result.heavyParticlesCleared)")
                            resultRow(label: "Wind/rain boosts protected", value: "\(result.helpfulFactorsProtected)")
                            if result.incorrectHits > 0 {
                                resultRow(label: "Incorrect hits", value: "\(result.incorrectHits)")
                            }
                            resultRow(label: "Best combo", value: "x\(result.maxCombo)")
                        }
                    }
                    .padding(.horizontal)

                    if !recap.isEmpty {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                                SectionHeader(title: "Persistence vs. removal — how AirCast forecasts tomorrow")
                                ForEach(recap, id: \.self) { line in
                                    Text(line)
                                        .font(ACFont.caption())
                                        .foregroundStyle(ACColor.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }

                    // "So what does this number mean for me" — real EPA-style
                    // guidance for the round's forecast category. This text
                    // already existed in the app (`AQICategory.guidance`) but
                    // was displayed nowhere at all before this; the round's
                    // persistence/removal mechanics explain *why* the number
                    // moves, this explains what the resulting number *means*.
                    if let forecastScenario {
                        let guidance = GameEducationFacts.healthGuidance(forecastPM25: forecastScenario.forecastPM25)
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: ACSpacing.xs) {
                                Label("What \(guidance.category.label.lowercased()) air means", systemImage: guidance.category.symbolName)
                                    .font(ACFont.cardTitle())
                                    .foregroundStyle(guidance.category.color)
                                Text(guidance.guidance)
                                    .font(ACFont.caption())
                                    .foregroundStyle(ACColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                        .padding(.horizontal)
                    }

                    if let forecastScenario {
                        VStack(spacing: 2) {
                            Text("AirCast forecast")
                                .font(ACFont.micro())
                                .foregroundStyle(ACColor.textTertiary)
                            Text("\(Int(forecastScenario.forecastPM25.rounded())) µg/m³")
                                .font(ACFont.numericEmphasis())
                                .foregroundStyle(ACColor.textPrimary)
                            // Same provenance labeling every other screen
                            // uses (work order §15/§27) — this number is
                            // never shown without its "Demo data · ..." /
                            // "Forecast · generated ..." source.
                            FreshnessBadge(provenance: forecastScenario.provenance)
                        }
                    }

                    // A real fact about the research behind the number above
                    // — points toward Model Lab for anyone curious enough to
                    // want the full methodology, without repeating it here.
                    Text(GameEducationFacts.datasetFact)
                        .font(ACFont.micro())
                        .foregroundStyle(ACColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ACSpacing.lg)

                    VStack(spacing: ACSpacing.sm) {
                        Button("Play Again", action: onPlayAgain)
                            .buttonStyle(.acPrimary)
                        Button("Back to Forecast", action: onBackToForecast)
                            .buttonStyle(.acSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, ACSpacing.sm)
                }
                .padding(.bottom, ACSpacing.xl)
            }
        }
        .navigationTitle("Round Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ACFont.caption())
                .foregroundStyle(ACColor.textSecondary)
            Spacer()
            Text(value)
                .font(ACFont.cardTitle())
                .foregroundStyle(ACColor.textPrimary)
        }
    }
}

#Preview("Clean Air Defender — Result") {
    NavigationStack {
        CleanAirDefenderResultView(
            result: GameResult(
                score: 1420,
                particlesCleared: 18,
                heavyParticlesCleared: 3,
                helpfulFactorsProtected: 3,
                incorrectHits: 0,
                maxCombo: 5,
                duration: 40,
                playedAt: .now
            ),
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
            onPlayAgain: {},
            onBackToForecast: {}
        )
    }
}
