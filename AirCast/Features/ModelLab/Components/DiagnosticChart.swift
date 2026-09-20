import SwiftUI
import Charts

/// The interactive evaluation diagnostic — every one of the 1,052 held-out
/// test-set points behind the model's reported MAE/RMSE, real per-point
/// data, not a summary illustration. Toggle between two honest ways to look
/// at the same errors: observed-vs-predicted (how close is each point to
/// the ideal diagonal?) and residuals over time (does the model get worse
/// in any particular period, i.e. is there drift?).
struct DiagnosticChart: View {
    let points: [BundledTestResidualsFile.TestPoint]

    enum Mode: String, CaseIterable, Identifiable {
        case observedVsPredicted = "Observed vs Predicted"
        case residualsOverTime = "Residuals Over Time"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .observedVsPredicted
    @State private var selected: BundledTestResidualsFile.TestPoint?

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Evaluation diagnostics", subtitle: "\(points.count) held-out test points — every one behind the reported MAE/RMSE")

                Picker("Diagnostic", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                chart
                    .frame(height: 220)

                if let selected {
                    HStack(spacing: ACSpacing.md) {
                        statLabel("Date", selected.date)
                        statLabel("Observed", "\(selected.observed.formatted(decimals: 1)) µg/m³")
                        statLabel("Predicted", "\(selected.predicted.formatted(decimals: 1)) µg/m³")
                        statLabel("Error", "\(selected.residual > 0 ? "+" : "")\(selected.residual.formatted(decimals: 1))")
                    }
                    .font(ACFont.micro())
                } else {
                    Text(mode == .observedVsPredicted
                         ? "Points closer to the diagonal line are more accurate predictions. Drag to inspect any point."
                         : "Each point is one test-set day's error (observed minus predicted). Drag to inspect."
                    )
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).foregroundStyle(ACColor.textTertiary)
            Text(value).fontWeight(.semibold).foregroundStyle(ACColor.textPrimary)
        }
    }

    @ViewBuilder
    private var chart: some View {
        switch mode {
        case .observedVsPredicted:
            observedVsPredictedChart
        case .residualsOverTime:
            residualsOverTimeChart
        }
    }

    private var maxValue: Double {
        max(points.map(\.observed).max() ?? 50, points.map(\.predicted).max() ?? 50) * 1.05
    }

    private var observedVsPredictedChart: some View {
        Chart {
            LineMark(x: .value("Predicted", 0.0), y: .value("Observed", 0.0))
            LineMark(x: .value("Predicted", maxValue), y: .value("Observed", maxValue))
                .foregroundStyle(ACColor.textTertiary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(points) { point in
                PointMark(
                    x: .value("Predicted", point.predicted),
                    y: .value("Observed", point.observed)
                )
                .foregroundStyle(ACColor.forecastSeries.opacity(selected == nil || selected?.id == point.id ? 0.55 : 0.15))
                .symbolSize(selected?.id == point.id ? 60 : 14)
            }
        }
        .chartXAxisLabel("Predicted (µg/m³)")
        .chartYAxisLabel("Observed (µg/m³)")
        .chartOverlay { proxy in
            dragOverlay(proxy: proxy) { location, geometry in
                guard let plotFrame = proxy.plotFrame else { return }
                let origin = geometry[plotFrame].origin
                guard let predicted: Double = proxy.value(atX: location.x - origin.x) else { return }
                selected = points.min { abs($0.predicted - predicted) < abs($1.predicted - predicted) }
            }
        }
    }

    private var residualsOverTimeChart: some View {
        Chart {
            RuleMark(y: .value("Zero", 0.0))
                .foregroundStyle(ACColor.textTertiary)
                .lineStyle(StrokeStyle(lineWidth: 1))

            ForEach(points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Residual", point.residual)
                )
                .foregroundStyle((point.residual >= 0 ? ACColor.warning : ACColor.positive).opacity(selected == nil || selected?.id == point.id ? 0.5 : 0.12))
                .symbolSize(selected?.id == point.id ? 60 : 10)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxisLabel("Observed − Predicted (µg/m³)")
        .chartOverlay { proxy in
            dragOverlay(proxy: proxy) { location, geometry in
                guard let plotFrame = proxy.plotFrame else { return }
                let origin = geometry[plotFrame].origin
                guard let date: String = proxy.value(atX: location.x - origin.x) else { return }
                selected = points.first { $0.date == date } ?? selected
            }
        }
    }

    private func dragOverlay(proxy: ChartProxy, onDrag: @escaping (CGPoint, GeometryProxy) -> Void) -> some View {
        GeometryReader { geometry in
            Rectangle().fill(Color.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in onDrag(value.location, geometry) }
                )
        }
    }
}

private extension Double {
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

#Preview("DiagnosticChart") {
    DiagnosticChart(points: BundledResearchData.testResiduals.testPoints)
        .padding()
        .background(ACColor.background)
}
