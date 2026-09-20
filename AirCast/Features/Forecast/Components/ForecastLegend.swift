import SwiftUI

/// Explicit observed-vs-forecast legend plus model version — required so the
/// two series (and what's powering the forecast one) are never ambiguous.
struct ForecastLegend: View {
    var modelVersion: String?

    var body: some View {
        HStack(spacing: ACSpacing.md) {
            swatch(color: ACColor.observedSeries, label: "Observed", style: .solid)
            swatch(color: ACColor.forecastSeries, label: "Forecast", style: .dashed)
            Spacer()
            if let modelVersion {
                Text("Model \(modelVersion)")
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend: solid line is observed data, dashed line is forecast\(modelVersion.map { ", model version \($0)" } ?? "").")
    }

    private enum LineStyleKind { case solid, dashed }

    private func swatch(color: Color, label: String, style: LineStyleKind) -> some View {
        HStack(spacing: ACSpacing.xxs) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 2.5)
                .overlay {
                    if style == .dashed {
                        Rectangle()
                            .fill(ACColor.background)
                            .frame(width: 4, height: 2.5)
                    }
                }
            Text(label)
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textSecondary)
        }
    }
}

#Preview("ForecastLegend") {
    ForecastLegend(modelVersion: "ols-1.0")
        .padding()
        .background(ACColor.background)
}
