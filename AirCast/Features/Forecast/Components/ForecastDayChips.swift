import SwiftUI

/// A row of tappable, VoiceOver-friendly chips — the accessible, non-gesture
/// alternative to dragging the chart. Deliberately shows only the
/// "headline" points (the latest observation plus each forecast day), not
/// every hourly observation, so it stays scannable at a glance.
struct ForecastDayChips: View {
    let points: [ForecastSelection]
    @Binding var selection: ForecastSelection?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ACSpacing.xs) {
                ForEach(points) { point in
                    chip(for: point)
                }
            }
        }
    }

    private func chip(for point: ForecastSelection) -> some View {
        let isSelected = selection?.id == point.id
        return Button {
            selection = point
        } label: {
            VStack(spacing: 2) {
                Text(point.isObserved ? "Now" : point.timestamp.formatted(.dateTime.weekday(.abbreviated)))
                    .font(ACFont.micro())
                Text("\(Int(point.pm25.rounded()))")
                    .font(ACFont.caption())
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, ACSpacing.sm)
            .padding(.vertical, ACSpacing.xs)
            .background(
                Capsule().fill(isSelected ? point.category.color.opacity(0.28) : ACColor.surfaceSecondary)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? point.category.color : .clear, lineWidth: 1.5)
            )
            .foregroundStyle(ACColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(point.isObserved ? "Observed" : "Forecast") \(point.timestamp.formatted(.dateTime.weekday(.wide))), \(Int(point.pm25.rounded())) micrograms per cubic meter, \(point.category.label)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("ForecastDayChips") {
    struct PreviewHost: View {
        @State private var selection: ForecastSelection? = .forecast(SampleData.forecastPoint)
        var body: some View {
            ForecastDayChips(points: [.observation(SampleData.observation), .forecast(SampleData.forecastPoint)], selection: $selection)
                .padding()
                .background(ACColor.background)
        }
    }
    return PreviewHost()
}
