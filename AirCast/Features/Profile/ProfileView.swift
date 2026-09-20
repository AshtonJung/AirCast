import SwiftUI

/// Profile/More: prediction accuracy trend, completed challenges, personal
/// best, a small achievement set, and the paths to Model Lab and Settings —
/// everything kept local, lightweight, and free of social/ranking features.
struct ProfileView: View {
    @State var viewModel: ProfileViewModel
    let modelLabViewModel: ModelLabViewModel
    let currentScenario: DemoScenario
    let onSelectScenario: (DemoScenario) async -> Void
    let onResetDemo: () async -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                ACColor.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(modelCard: modelLabViewModel.modelCard, currentScenario: currentScenario, onSelectScenario: onSelectScenario, onResetDemo: onResetDemo)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                VStack(spacing: ACSpacing.md) {
                    LoadingCardSkeleton().frame(height: 120)
                    LoadingCardSkeleton().frame(height: 160)
                }
                .padding()
            }
        case .failed(let kind, let message) where viewModel.challenges.isEmpty:
            ScrollView {
                ACStateView(kind: kind, title: "Couldn't load Profile", message: message, actionTitle: "Try Again", action: { Task { await viewModel.load() } })
                    .padding(.top, ACSpacing.xxl)
                    .padding()
            }
        default:
            loaded
        }
    }

    private var loaded: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ACSpacing.md) {
                statsRow

                ScoreTrendChart(trend: viewModel.scoreTrend)

                AchievementGrid(achievements: viewModel.achievements)

                NavigationLink {
                    ModelLabView(viewModel: modelLabViewModel)
                } label: {
                    SurfaceCard {
                        HStack(spacing: ACSpacing.sm) {
                            Image(systemName: "flask")
                                .foregroundStyle(ACColor.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Statistics / Model Lab")
                                    .font(ACFont.cardTitle())
                                    .foregroundStyle(ACColor.textPrimary)
                                Text("The research and evaluation behind every forecast")
                                    .font(ACFont.caption())
                                    .foregroundStyle(ACColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(ACColor.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .padding(.bottom, ACSpacing.xl)
        }
        .refreshable { await viewModel.load() }
    }

    private var statsRow: some View {
        HStack(spacing: ACSpacing.sm) {
            statTile(title: "Best score", value: viewModel.bestScore.map { "\(Int($0.rounded()))" } ?? "—", icon: "star")
            statTile(title: "Best error", value: viewModel.bestAbsoluteError.map { String(format: "±%.1f", $0) } ?? "—", icon: "scope")
            statTile(title: "Beat model", value: "\(viewModel.timesBeatModel)×", icon: "trophy")
        }
    }

    private func statTile(title: String, value: String, icon: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.xxs) {
                Image(systemName: icon).foregroundStyle(ACColor.accent)
                Text(value)
                    .font(ACFont.numericEmphasis())
                    .foregroundStyle(ACColor.textPrimary)
                Text(title)
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("ProfileView") {
    let repository = DemoAirQualityRepository(scenario: .challengeRevealReady)
    ProfileView(
        viewModel: ProfileViewModel(repository: repository),
        modelLabViewModel: ModelLabViewModel(repository: repository),
        currentScenario: .challengeRevealReady,
        onSelectScenario: { _ in },
        onResetDemo: {}
    )
}
