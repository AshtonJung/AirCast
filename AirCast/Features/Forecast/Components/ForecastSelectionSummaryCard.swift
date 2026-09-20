import SwiftUI

/// The "forecast summary for the selected horizon" — updates live as the
/// user drags the chart or taps a day chip. Always states plainly whether
/// the shown number is an observation or a forecast.
struct ForecastSelectionSummaryCard: View {
    let selection: ForecastSelection

    private var uncertaintyText: String? {
        guard let uncertainty = selection.uncertainty else { return nil }
        switch uncertainty.method {
        case .computedInterval:
            guard let lower = uncertainty.lowerBound, let upper = uncertainty.upperBound else { return nil }
            let coverageText = uncertainty.coverage.map { "\(Int($0 * 100))% range" } ?? "Estimated range"
            return "\(Int(lower.rounded()))–\(Int(upper.rounded())) µg/m³ · \(coverageText)"
        case .qualitativeHeuristic:
            return uncertainty.qualitativeLevel?.label ?? "Confidence unavailable"
        }
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                HStack {
                    Label(selection.isObserved ? "Observed" : "Forecast", systemImage: selection.isObserved ? "checkmark.circle" : "sparkles")
                        .font(ACFont.micro())
                        .foregroundStyle(selection.isObserved ? ACColor.observedSeries : ACColor.forecastSeries)
                    Spacer()
                    Text(selection.timestamp.formatted(date: .abbreviated, time: selection.isObserved ? .shortened : .omitted))
                        .font(ACFont.micro())
                        .foregroundStyle(ACColor.textTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: ACSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: ACSpacing.xxs) {
                        Text("\(Int(selection.pm25.rounded()))")
                            .font(ACFont.numericEmphasis())
                            .contentTransition(.numericText())
                        Text("µg/m³")
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                    }
                    AQIStatusPill(category: selection.category)
                }

                if let uncertaintyText {
                    Text(uncertaintyText)
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                }

                FreshnessBadge(provenance: selection.provenance)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(ACMotion.quickSpring, value: selection.id)
        .accessibilityElement(children: .combine)
    }
}

#Preview("ForecastSelectionSummaryCard") {
    VStack(spacing: ACSpacing.md) {
        ForecastSelectionSummaryCard(selection: .observation(SampleData.observation))
        ForecastSelectionSummaryCard(selection: .forecast(SampleData.forecastPoint))
    }
    .padding()
    .background(ACColor.background)
}
