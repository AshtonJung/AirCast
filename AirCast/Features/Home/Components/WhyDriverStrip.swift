import SwiftUI

/// A compact horizontal strip of the top forecast drivers. Association
/// language only ("pushing PM2.5 higher/lower") — never causal claims.
struct WhyDriverStrip: View {
    let drivers: [ExplanationDriver]
    var onSelect: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ACSpacing.sm) {
            SectionHeader(title: "Why this forecast?", trailingActionTitle: drivers.isEmpty ? nil : "See forecast", trailingAction: drivers.isEmpty ? nil : onSelect)

            if drivers.isEmpty {
                Text("Not enough recent data to explain this forecast yet.")
                    .font(ACFont.caption())
                    .foregroundStyle(ACColor.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ACSpacing.sm) {
                        ForEach(drivers.prefix(3)) { driver in
                            DriverChip(driver: driver)
                        }
                    }
                }
            }
        }
    }
}

private struct DriverChip: View {
    let driver: ExplanationDriver

    var body: some View {
        VStack(alignment: .leading, spacing: ACSpacing.xxs) {
            HStack(spacing: ACSpacing.xxs) {
                Image(systemName: driver.kind.symbolName)
                Image(systemName: driver.direction.symbolName)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(ACColor.accent)

            Text(driver.kind.label)
                .font(ACFont.caption())
                .fontWeight(.semibold)
                .foregroundStyle(ACColor.textPrimary)

            Text(driver.direction.label)
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textSecondary)

            if driver.basis == .ruleBased {
                Text("Rule-based")
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
            }
        }
        .padding(ACSpacing.sm)
        .frame(width: 132, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ACRadius.md, style: .continuous)
                .fill(ACColor.surfaceSecondary)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("WhyDriverStrip") {
    WhyDriverStrip(drivers: [SampleData.driver, SampleData.driver, SampleData.driver])
        .padding()
        .background(ACColor.background)
}
