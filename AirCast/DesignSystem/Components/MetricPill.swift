import SwiftUI

/// A compact labeled value chip, e.g. "Wind · 12 km/h" or an AQI status pill.
/// Always pairs a symbol with color so status is never conveyed by color alone.
struct MetricPill: View {
    let symbolName: String
    let label: String
    var tint: Color = ACColor.accent

    var body: some View {
        HStack(spacing: ACSpacing.xxs) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(ACFont.micro())
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, ACSpacing.sm)
        .padding(.vertical, ACSpacing.xxs)
        .background(
            Capsule().fill(tint.opacity(0.14))
        )
        .accessibilityElement(children: .combine)
    }
}

/// A pill specifically for AQI/PM2.5 status, backed by `AQICategory` so color
/// + label + icon are always consistent with the rest of the app.
struct AQIStatusPill: View {
    let category: AQICategory

    var body: some View {
        MetricPill(symbolName: category.symbolName, label: category.shortLabel, tint: category.color)
    }
}

#Preview("MetricPill") {
    VStack(alignment: .leading, spacing: ACSpacing.sm) {
        MetricPill(symbolName: "wind", label: "12 km/h NW")
        MetricPill(symbolName: "cloud.rain", label: "0.2 mm/h")
        ForEach(AQICategory.allCases) { category in
            AQIStatusPill(category: category)
        }
    }
    .padding()
    .background(ACColor.background)
}
