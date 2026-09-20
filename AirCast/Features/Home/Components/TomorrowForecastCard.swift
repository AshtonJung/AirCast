import SwiftUI

/// The tomorrow forecast card — a point forecast paired with its uncertainty,
/// never presented as a bare exact promise.
struct TomorrowForecastCard: View {
    let point: PM25ForecastPoint

    private var rangeText: String? {
        switch point.uncertainty.method {
        case .computedInterval:
            guard let lower = point.uncertainty.lowerBound, let upper = point.uncertainty.upperBound else { return nil }
            return "\(Int(lower.rounded()))–\(Int(upper.rounded())) µg/m³"
        case .qualitativeHeuristic:
            return nil
        }
    }

    private var confidenceText: String {
        switch point.uncertainty.method {
        case .computedInterval:
            if let coverage = point.uncertainty.coverage {
                return "\(Int(coverage * 100))% range"
            }
            return "Estimated range"
        case .qualitativeHeuristic:
            return point.uncertainty.qualitativeLevel?.label ?? "Confidence unavailable"
        }
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Tomorrow", subtitle: point.targetTime.formatted(.dateTime.weekday(.wide)))

                HStack(alignment: .firstTextBaseline, spacing: ACSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: ACSpacing.xxs) {
                        Text("\(Int(point.pm25.rounded()))")
                            .font(ACFont.numericEmphasis())
                        Text("µg/m³")
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                    }
                    AQIStatusPill(category: point.category)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let rangeText {
                        Text(rangeText)
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                    }
                    Text(confidenceText)
                        .font(ACFont.micro())
                        .foregroundStyle(ACColor.textTertiary)
                }

                FreshnessBadge(provenance: point.provenance)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tomorrow's forecast: \(point.category.label), \(Int(point.pm25.rounded())) micrograms per cubic meter, \(confidenceText)")
    }
}

#Preview("TomorrowForecastCard — computed interval") {
    TomorrowForecastCard(point: SampleData.forecastPoint)
        .padding()
        .background(ACColor.background)
}

#Preview("TomorrowForecastCard — qualitative") {
    TomorrowForecastCard(
        point: PM25ForecastPoint(
            targetTime: Date().addingTimeInterval(24 * 3600),
            pm25: 98,
            uncertainty: .qualitative(.low),
            provenance: SampleData.forecastPoint.provenance
        )
    )
    .padding()
    .background(ACColor.background)
}
