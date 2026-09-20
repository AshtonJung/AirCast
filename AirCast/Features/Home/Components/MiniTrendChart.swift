import SwiftUI
import Charts

/// A draggable mini sparkline of recent PM2.5, inviting exploration and
/// linking through to the full interactive Forecast screen. Drag to inspect
/// a specific reading; tap anywhere (or the header action) to jump to Forecast.
struct MiniTrendChart: View {
    let observations: [AirQualityObservation] // newest-first
    var onOpenForecast: (() -> Void)? = nil

    @State private var selected: AirQualityObservation?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chronological: [AirQualityObservation] { observations.reversed() }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Last 24 hours", trailingActionTitle: "Open Forecast", trailingAction: onOpenForecast)

                if chronological.count < 2 {
                    Text("Not enough recent data for a trend yet.")
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                } else {
                    chart
                        .frame(height: 90)

                    HStack {
                        if let selected {
                            Text(selected.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(ACFont.micro())
                                .foregroundStyle(ACColor.textSecondary)
                            Spacer()
                            Text("\(Int(selected.pm25.rounded())) µg/m³")
                                .font(ACFont.micro())
                                .fontWeight(.semibold)
                                .foregroundStyle(ACColor.textPrimary)
                        } else {
                            Text("Drag to inspect a reading")
                                .font(ACFont.micro())
                                .foregroundStyle(ACColor.textTertiary)
                        }
                    }
                    .animation(reduceMotion ? nil : ACMotion.quickSpring, value: selected?.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = chronological.first, let last = chronological.last else { return "Recent trend unavailable." }
        return "Last 24 hours, from \(Int(first.pm25.rounded())) to \(Int(last.pm25.rounded())) micrograms per cubic meter."
    }

    private var chart: some View {
        Chart(chronological) { observation in
            LineMark(
                x: .value("Time", observation.timestamp),
                y: .value("PM2.5", observation.pm25)
            )
            .foregroundStyle(ACColor.forecastSeries)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            AreaMark(
                x: .value("Time", observation.timestamp),
                y: .value("PM2.5", observation.pm25)
            )
            .foregroundStyle(
                LinearGradient(colors: [ACColor.forecastSeries.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)
            )
            .interpolationMethod(.catmullRom)

            if let selected, selected.id == observation.id {
                PointMark(
                    x: .value("Time", observation.timestamp),
                    y: .value("PM2.5", observation.pm25)
                )
                .foregroundStyle(ACColor.forecastSeries)
                .symbolSize(70)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in selected = nil }
                    )
            }
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let origin = geometry[plotFrameAnchor].origin
        let relativeX = location.x - origin.x
        guard let date: Date = proxy.value(atX: relativeX) else { return }
        guard let closest = chronological.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }) else { return }
        if closest.id != selected?.id { selected = closest }
    }
}

#Preview("MiniTrendChart") {
    MiniTrendChart(observations: (0..<12).map { i in
        AirQualityObservation(
            timestamp: SampleData.now.addingTimeInterval(Double(-i) * 3600),
            pm25: 18 + Double.random(in: -3...3),
            locationName: "Sample City",
            provenance: SampleData.observation.provenance
        )
    })
    .padding()
    .background(ACColor.background)
}
