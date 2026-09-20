import SwiftUI
import Charts

/// A simple line of every resolved prediction's score over time — the
/// "improvement" story, built from real scored challenges only.
struct ScoreTrendChart: View {
    let trend: [(date: Date, score: Double)]

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Accuracy trend", subtitle: "Score per resolved prediction, oldest to newest")

                if trend.count < 2 {
                    Text("Resolve a few more predictions to see your trend.")
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                } else {
                    Chart(Array(trend.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(ACColor.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(ACColor.accent)
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 140)
                    .accessibilityLabel(accessibilitySummary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilitySummary: String {
        guard let first = trend.first, let last = trend.last else { return "No score trend yet." }
        return "Score trend from \(Int(first.score)) to \(Int(last.score)) out of 100."
    }
}

#Preview("ScoreTrendChart") {
    ScoreTrendChart(trend: [
        (Date().addingTimeInterval(-86400 * 4), 62),
        (Date().addingTimeInterval(-86400 * 3), 71),
        (Date().addingTimeInterval(-86400 * 2), 58),
        (Date().addingTimeInterval(-86400 * 1), 84),
        (Date(), 91),
    ])
    .padding()
    .background(ACColor.background)
}
