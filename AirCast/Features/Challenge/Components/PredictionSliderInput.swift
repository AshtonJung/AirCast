import SwiftUI

/// The tactile prediction control: a big live-updating number, its AQI
/// category pill, and a color-tinted slider with haptic ticks every 5 µg/m³
/// so dialing in a guess feels physical, not like typing into a text field.
struct PredictionSliderInput: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...200

    @State private var hapticBucket = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var category: AQICategory { AQICategory.classify(pm25: value) }

    var body: some View {
        VStack(spacing: ACSpacing.md) {
            VStack(spacing: ACSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: ACSpacing.xs) {
                    Text("\(Int(value.rounded()))")
                        .font(ACFont.heroValue())
                        .contentTransition(.numericText())
                        .foregroundStyle(ACColor.textPrimary)
                    Text("µg/m³")
                        .font(ACFont.cardTitle())
                        .foregroundStyle(ACColor.textSecondary)
                }
                .animation(reduceMotion ? nil : ACMotion.quickSpring, value: Int(value.rounded()))

                AQIStatusPill(category: category)
            }

            VStack(spacing: ACSpacing.xxs) {
                Slider(
                    value: $value,
                    in: range,
                    step: 1,
                    minimumValueLabel: Text("0").font(ACFont.micro()).foregroundStyle(ACColor.textTertiary),
                    maximumValueLabel: Text("200").font(ACFont.micro()).foregroundStyle(ACColor.textTertiary)
                ) {
                    Text("Predicted PM2.5")
                }
                .tint(category.color)
                .onChange(of: value) { _, newValue in
                    let bucket = Int(newValue / 5)
                    if bucket != hapticBucket { hapticBucket = bucket }
                }

                Text("Drag to set your prediction for tomorrow")
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
            }
        }
        .sensoryFeedback(.selection, trigger: hapticBucket)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Predicted PM2.5: \(Int(value.rounded())) micrograms per cubic meter, \(category.label)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
}

#Preview("PredictionSliderInput") {
    struct PreviewHost: View {
        @State private var value: Double = 22
        var body: some View {
            SurfaceCard {
                PredictionSliderInput(value: $value)
            }
            .padding()
            .background(ACColor.background)
        }
    }
    return PreviewHost()
}
