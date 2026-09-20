import SwiftUI
import Charts

/// The interactive observed→forecast timeline. Solid line = real
/// observations; dashed line = forecast. A vertical range bar marks the one
/// point with a real, validated numeric interval; later forecast points are
/// drawn lower-opacity to visually read as "less certain" without a
/// fabricated numeric band. Drag anywhere to move the crosshair.
struct ForecastChart: View {
    let observations: [AirQualityObservation] // chronological
    let forecastPoints: [PM25ForecastPoint] // chronological
    @Binding var selection: ForecastSelection?
    var onSelectionChanged: ((Date) -> Void)? = nil

    var body: some View {
        chart
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let firstObs = observations.first, let lastObs = observations.last else { return "Forecast chart" }
        var text = "Observed PM2.5 from \(Int(firstObs.pm25.rounded())) to \(Int(lastObs.pm25.rounded())) micrograms per cubic meter over the last 24 hours."
        if let firstForecast = forecastPoints.first {
            text += " Tomorrow's forecast: \(Int(firstForecast.pm25.rounded())) micrograms per cubic meter, \(firstForecast.category.label)."
        }
        return text
    }

    @ChartContentBuilder
    private func observedMarks() -> some ChartContent {
        ForEach(observations) { observation in
            LineMark(
                x: .value("Time", observation.timestamp),
                y: .value("PM2.5", observation.pm25),
                series: .value("Series", "Observed")
            )
            .foregroundStyle(ACColor.observedSeries)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private func forecastMarks() -> some ChartContent {
        // Bridge the gap: connect the last observation to the first forecast
        // point so the dashed forecast line visibly continues from "now."
        if let lastObserved = observations.last, let firstForecast = forecastPoints.first {
            LineMark(
                x: .value("Time", lastObserved.timestamp),
                y: .value("PM2.5", lastObserved.pm25),
                series: .value("Series", "Forecast")
            )
            .foregroundStyle(ACColor.forecastSeries)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))

            LineMark(
                x: .value("Time", firstForecast.targetTime),
                y: .value("PM2.5", firstForecast.pm25),
                series: .value("Series", "Forecast")
            )
            .foregroundStyle(ACColor.forecastSeries)
        }

        ForEach(forecastPoints) { point in
            LineMark(
                x: .value("Time", point.targetTime),
                y: .value("PM2.5", point.pm25),
                series: .value("Series", "Forecast")
            )
            .foregroundStyle(ACColor.forecastSeries)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))

            PointMark(
                x: .value("Time", point.targetTime),
                y: .value("PM2.5", point.pm25)
            )
            .foregroundStyle(ACColor.forecastSeries.opacity(point.uncertainty.method == .computedInterval ? 1 : 0.55))
            .symbol(.diamond)
            .symbolSize(selection?.id == ForecastSelection.forecast(point).id ? 90 : 45)

            if point.uncertainty.method == .computedInterval,
               let lower = point.uncertainty.lowerBound, let upper = point.uncertainty.upperBound {
                RuleMark(
                    x: .value("Time", point.targetTime),
                    yStart: .value("Lower", lower),
                    yEnd: .value("Upper", upper)
                )
                .foregroundStyle(ACColor.uncertaintyBand)
                .lineStyle(StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
    }

    private var chart: some View {
        Chart {
            observedMarks()
            forecastMarks()

            if let selection {
                RuleMark(x: .value("Selected", selection.timestamp))
                    .foregroundStyle(ACColor.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(x: .value("Time", selection.timestamp), y: .value("PM2.5", selection.pm25))
                    .foregroundStyle(selection.isObserved ? ACColor.observedSeries : ACColor.forecastSeries)
                    .symbolSize(110)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let originX = geometry[plotFrame].origin.x
                                guard let date: Date = proxy.value(atX: value.location.x - originX) else { return }
                                onSelectionChanged?(date)
                            }
                    )
            }
        }
    }
}

#Preview("ForecastChart") {
    struct PreviewHost: View {
        @State private var selection: ForecastSelection?
        var body: some View {
            ForecastChart(
                observations: (0..<24).reversed().map { i in
                    AirQualityObservation(timestamp: SampleData.now.addingTimeInterval(Double(-i) * 3600), pm25: 15 + Double.random(in: -2...2), locationName: "Sample", provenance: SampleData.observation.provenance)
                },
                forecastPoints: [SampleData.forecastPoint],
                selection: $selection
            )
            .padding()
            .background(ACColor.background)
        }
    }
    return PreviewHost()
}
