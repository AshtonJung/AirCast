import SwiftUI

/// The reveal for one resolved challenge: your prediction vs. AirCast's
/// forecast vs. what was actually observed, laid out so the two errors are
/// directly comparable at a glance, plus the documented, non-arbitrary
/// score. Animates in once (not a slot-machine effect) — satisfying without
/// being casino-like, per the guide's rule against manipulative reveals.
struct ChallengeRevealCard: View {
    let challenge: PredictionChallenge

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.md) {
                HStack {
                    Text(challenge.challengeDate.formatted(date: .abbreviated, time: .omitted))
                        .font(ACFont.cardTitle())
                        .foregroundStyle(ACColor.textPrimary)
                    Spacer()
                    if let score = challenge.userScore {
                        scoreBadge(score)
                    }
                }

                HStack(spacing: ACSpacing.sm) {
                    column(title: "You", value: challenge.userPredictionPM25, error: challenge.userAbsoluteError, tint: ACColor.accent)
                    column(title: "AirCast", value: challenge.modelForecastPM25, error: challenge.modelAbsoluteError, tint: ACColor.textSecondary)
                    column(title: "Observed", value: challenge.observedPM25, error: nil, tint: ACColor.textPrimary, emphasized: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

                if let userError = challenge.userAbsoluteError, let modelError = challenge.modelAbsoluteError {
                    Text(learningText(userError: userError, modelError: modelError))
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: ACMotion.quickDuration) : ACMotion.expressiveSpring.delay(0.05)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func column(title: String, value: Double?, error: Double?, tint: Color, emphasized: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textTertiary)
            if let value {
                Text("\(Int(value.rounded()))")
                    .font(emphasized ? ACFont.numericEmphasis() : ACFont.cardTitle())
                    .foregroundStyle(tint)
            } else {
                Text("—")
                    .font(ACFont.cardTitle())
                    .foregroundStyle(ACColor.textTertiary)
            }
            if let error {
                Text("±\(String(format: "%.1f", error))")
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreBadge(_ score: Double) -> some View {
        Text("\(Int(score.rounded())) pts")
            .font(ACFont.caption())
            .fontWeight(.bold)
            .padding(.horizontal, ACSpacing.sm)
            .padding(.vertical, ACSpacing.xxs)
            .background(Capsule().fill(ACColor.accent.opacity(0.16)))
            .foregroundStyle(ACColor.accent)
    }

    private func learningText(userError: Double, modelError: Double) -> String {
        let diff = userError - modelError
        if abs(diff) < 1 {
            return "You and the model were about equally close — within 1 µg/m³ of each other."
        } else if diff < 0 {
            return "You beat the model by \(String(format: "%.1f", abs(diff))) µg/m³ this time."
        } else {
            return "The model was \(String(format: "%.1f", diff)) µg/m³ closer than your prediction this time."
        }
    }
}

#Preview("ChallengeRevealCard") {
    ChallengeRevealCard(
        challenge: PredictionChallenge(
            challengeDate: Date().addingTimeInterval(-86400),
            userPredictionPM25: 12.3,
            cutoffAt: Date().addingTimeInterval(-3600),
            modelForecastPM25: 10.1,
            observedPM25: 10.9,
            resolvedAt: Date()
        )
    )
    .padding()
    .background(ACColor.background)
}
