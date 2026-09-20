import SwiftUI

/// Every reported metric alongside its naive-baseline comparison — an
/// animated bar makes "does this actually beat just guessing tomorrow
/// looks like today?" visible at a glance, honestly (the model wins by a
/// modest margin here, not a dramatic one, and the bars show that plainly).
struct EvaluationMetricsCard: View {
    let metrics: [EvaluationMetric]

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.md) {
                SectionHeader(title: "Evaluation", subtitle: "Model vs. naive persistence baseline (\"tomorrow = today\")")

                ForEach(metrics) { metric in
                    metricRow(metric)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: ACMotion.quickDuration) : ACMotion.standardSpring.delay(0.1)) {
                appeared = true
            }
        }
    }

    private func metricRow(_ metric: EvaluationMetric) -> some View {
        let maxValue = max(metric.value, metric.baselineValue ?? metric.value) * 1.15
        return VStack(alignment: .leading, spacing: ACSpacing.xxs) {
            HStack {
                Text(metric.name)
                    .font(ACFont.cardTitle())
                    .foregroundStyle(ACColor.textPrimary)
                Spacer()
                Text("\(metric.value.formatted(decimals: 2)) \(metric.unit)")
                    .font(ACFont.cardTitle())
                    .foregroundStyle(ACColor.accent)
            }
            Text(metric.definition)
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textTertiary)

            bar(label: "AirCast model", value: metric.value, max: maxValue, color: ACColor.accent)
            if let baseline = metric.baselineValue {
                bar(label: "Persistence baseline", value: baseline, max: maxValue, color: ACColor.textTertiary)
            }
        }
    }

    private func bar(label: String, value: Double, max maxValue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ACColor.surfaceSecondary)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * (appeared ? min(1, value / maxValue) : 0))
                }
            }
            .frame(height: 8)
            Text("\(label) · \(value.formatted(decimals: 2))")
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textTertiary)
        }
    }
}

private extension Double {
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

#Preview("EvaluationMetricsCard") {
    EvaluationMetricsCard(metrics: [
        EvaluationMetric(name: "MAE (test)", definition: "Mean Absolute Error.", value: 2.46, unit: "µg/m³", baselineValue: 2.65),
        EvaluationMetric(name: "RMSE (test)", definition: "Root Mean Squared Error.", value: 3.89, unit: "µg/m³", baselineValue: 4.22),
    ])
    .padding()
    .background(ACColor.background)
}
