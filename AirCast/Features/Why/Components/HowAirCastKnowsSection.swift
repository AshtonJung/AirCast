import SwiftUI

/// The "How AirCast knows" disclosure: source, model type/version, and
/// limitations, straight from the same `ModelCard` Model Lab uses — never a
/// separate, potentially-diverging copy of these claims.
struct HowAirCastKnowsSection: View {
    let modelCard: ModelCard
    var onOpenModelLab: (() -> Void)? = nil

    @State private var expanded = false

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                Button {
                    withAnimation(ACMotion.quickSpring) { expanded.toggle() }
                } label: {
                    HStack {
                        Label("How AirCast knows", systemImage: "info.circle")
                            .font(ACFont.cardTitle())
                            .foregroundStyle(ACColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .foregroundStyle(ACColor.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)

                if expanded {
                    VStack(alignment: .leading, spacing: ACSpacing.sm) {
                        infoRow(label: "Data source", value: modelCard.dataset.sourceName)
                        infoRow(label: "Model", value: "\(modelCard.model.modelType) (\(modelCard.model.version))")
                        infoRow(label: "Coverage", value: modelCard.dataset.dateRangeDescription)

                        if let firstLimitation = modelCard.limitations.first {
                            Text(firstLimitation)
                                .font(ACFont.caption())
                                .foregroundStyle(ACColor.textTertiary)
                        }

                        if let onOpenModelLab {
                            Button("See full Model Lab", action: onOpenModelLab)
                                .buttonStyle(.acSecondary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textTertiary)
            Text(value)
                .font(ACFont.caption())
                .foregroundStyle(ACColor.textSecondary)
        }
    }
}

#Preview("HowAirCastKnowsSection") {
    HowAirCastKnowsSection(
        modelCard: ModelCard(
            researchQuestion: "Can next-day PM2.5 be forecast from recent trend and weather?",
            dataset: DatasetCard(sourceName: "EPA + NOAA, Orange County CA", geography: "Orange County, CA", dateRangeDescription: "2014-2025", sampleSize: 4328, variables: ["PM2.5", "Wind", "Precip"], lastUpdated: Date()),
            model: ModelDescription(modelType: "OLS regression", target: "Next-day PM2.5", inputs: ["pm25", "wind", "precip"], version: "ols-1.0", trainingValidationApproach: "Time-based split", deploymentStatus: "On-device"),
            metrics: [],
            limitations: ["Simple linear model, modest improvement over baseline."],
            responsibleUseStatement: "Not a substitute for official guidance.",
            relatedResearch: nil
        ),
        onOpenModelLab: {}
    )
    .padding()
    .background(ACColor.background)
}
