import SwiftUI

/// Statistics / Model Lab: the single screen a statistics-minded CAC judge
/// should be able to open and see real research — dataset, model,
/// evaluation against a baseline, per-point diagnostics, honest
/// limitations, and the deeper study that motivated the feature choices.
/// Every number here traces back to `ModelCard` / bundled research JSON;
/// nothing is typed directly into this view.
struct ModelLabView: View {
    @State var viewModel: ModelLabViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ACColor.background.ignoresSafeArea()
            content
        }
        .navigationTitle("Model Lab")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                VStack(spacing: ACSpacing.md) {
                    LoadingCardSkeleton().frame(height: 120)
                    LoadingCardSkeleton().frame(height: 220)
                    LoadingCardSkeleton().frame(height: 180)
                }
                .padding()
            }
        case .failed(let kind, let message) where viewModel.modelCard == nil:
            ScrollView {
                ACStateView(kind: kind, title: "Couldn't load Model Lab", message: message, actionTitle: "Try Again", action: { Task { await viewModel.load() } })
                    .padding(.top, ACSpacing.xxl)
                    .padding()
            }
        default:
            if let card = viewModel.modelCard {
                loaded(card)
            }
        }
    }

    private func loaded(_ card: ModelCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ACSpacing.md) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: ACSpacing.xs) {
                        Text("Research question")
                            .font(ACFont.micro())
                            .foregroundStyle(ACColor.textTertiary)
                        Text(card.researchQuestion)
                            .font(ACFont.body())
                            .foregroundStyle(ACColor.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                datasetCard(card.dataset)
                modelCard(card.model)

                EvaluationMetricsCard(metrics: card.metrics)

                DiagnosticChart(points: viewModel.testPoints)

                limitationsCard(card.limitations)

                if let research = card.relatedResearch {
                    RelatedResearchCard(research: research)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: ACSpacing.xxs) {
                        Label("Responsible use", systemImage: "info.circle")
                            .font(ACFont.micro())
                            .fontWeight(.semibold)
                            .foregroundStyle(ACColor.textSecondary)
                        Text(card.responsibleUseStatement)
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .padding(.bottom, ACSpacing.xl)
        }
        .refreshable { await viewModel.load() }
    }

    private func datasetCard(_ dataset: DatasetCard) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Dataset")
                infoRow("Source", dataset.sourceName)
                infoRow("Geography", dataset.geography)
                infoRow("Coverage", dataset.dateRangeDescription)
                if let sampleSize = dataset.sampleSize {
                    infoRow("Sample size", "\(sampleSize) consecutive-day pairs")
                }
                infoRow("Variables", dataset.variables.joined(separator: ", "))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func modelCard(_ model: ModelDescription) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Model", subtitle: "Version \(model.version)")
                infoRow("Type", model.modelType)
                infoRow("Target", model.target)
                infoRow("Inputs", model.inputs.joined(separator: ", "))
                infoRow("Training / validation", model.trainingValidationApproach)
                infoRow("Deployment", model.deploymentStatus)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func limitationsCard(_ limitations: [String]) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Limitations")
                ForEach(limitations, id: \.self) { limitation in
                    HStack(alignment: .top, spacing: ACSpacing.xxs) {
                        Text("•")
                        Text(limitation)
                    }
                    .font(ACFont.caption())
                    .foregroundStyle(ACColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
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

#Preview("ModelLabView") {
    NavigationStack {
        ModelLabView(viewModel: ModelLabViewModel(repository: DemoAirQualityRepository()))
    }
}
