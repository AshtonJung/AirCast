import SwiftUI

/// A full driver explanation card: direction, an animated contribution bar
/// (only when the model actually computed one — never a fabricated
/// percentage for rule-based drivers), the plain-language explanation, and
/// an honest "what changed since you last looked" line.
struct DriverDetailCard: View {
    let driver: ExplanationDriver
    var changeDescription: String? = nil

    @State private var barAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                HStack(spacing: ACSpacing.sm) {
                    ZStack {
                        Circle().fill(ACColor.accent.opacity(0.14)).frame(width: 36, height: 36)
                        Image(systemName: driver.kind.symbolName)
                            .foregroundStyle(ACColor.accent)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(driver.kind.label)
                            .font(ACFont.cardTitle())
                            .foregroundStyle(ACColor.textPrimary)
                        HStack(spacing: ACSpacing.xxs) {
                            Image(systemName: driver.direction.symbolName)
                            Text(driver.direction.label)
                        }
                        .font(ACFont.micro())
                        .foregroundStyle(ACColor.textSecondary)
                    }
                    Spacer()
                    basisBadge
                }

                if let contribution = driver.relativeContribution {
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ACColor.surfaceSecondary)
                                Capsule()
                                    .fill(driver.direction == .decreasesPM25 ? ACColor.positive : ACColor.warning)
                                    .frame(width: geo.size.width * (barAppeared ? contribution : 0))
                            }
                        }
                        .frame(height: 8)
                        Text("\(Int((contribution * 100).rounded()))% of the model's explained signal")
                            .font(ACFont.micro())
                            .foregroundStyle(ACColor.textTertiary)
                    }
                    .onAppear {
                        withAnimation(reduceMotion ? .easeInOut(duration: ACMotion.quickDuration) : ACMotion.standardSpring.delay(0.05)) {
                            barAppeared = true
                        }
                    }
                }

                Text(driver.explanation)
                    .font(ACFont.body())
                    .foregroundStyle(ACColor.textSecondary)

                if let changeDescription {
                    HStack(spacing: ACSpacing.xxs) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(changeDescription)
                    }
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var basisBadge: some View {
        Text(driver.basis == .modelComputed ? "Model" : "Rule-based")
            .font(ACFont.micro())
            .fontWeight(.semibold)
            .padding(.horizontal, ACSpacing.xs)
            .padding(.vertical, 3)
            .background(Capsule().fill(ACColor.surfaceSecondary))
            .foregroundStyle(ACColor.textSecondary)
    }
}

#Preview("DriverDetailCard") {
    VStack(spacing: ACSpacing.md) {
        DriverDetailCard(driver: SampleData.driver, changeDescription: "More influential than your last refresh.")
        DriverDetailCard(
            driver: ExplanationDriver(kind: .humidity, direction: .increasesPM25, basis: .ruleBased, explanation: "Rising humidity is associated with particulate growth in this region.")
        )
    }
    .padding()
    .background(ACColor.background)
}
