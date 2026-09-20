import SwiftUI

/// Integrated (not promotional-feeling) call-to-action into the Prediction
/// Challenge, surfaced as a natural continuation of "here's tomorrow's
/// forecast" rather than a banner ad.
struct ChallengeCTACard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard {
                HStack(spacing: ACSpacing.md) {
                    ZStack {
                        Circle().fill(ACColor.accent.opacity(0.16)).frame(width: 44, height: 44)
                        Image(systemName: "target")
                            .foregroundStyle(ACColor.accent)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Think you can beat the model?")
                            .font(ACFont.cardTitle())
                            .foregroundStyle(ACColor.textPrimary)
                        Text("Predict tomorrow's PM2.5 and see how close you get.")
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ACColor.textTertiary)
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prediction Challenge: think you can beat the model? Predict tomorrow's PM2.5.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("ChallengeCTACard") {
    ChallengeCTACard(action: {})
        .padding()
        .background(ACColor.background)
}
