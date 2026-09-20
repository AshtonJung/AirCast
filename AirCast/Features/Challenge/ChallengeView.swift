import SwiftUI

/// The Daily Prediction Challenge: predict tomorrow's PM2.5 with a tactile
/// slider, then compare your guess against AirCast's model and the real
/// observation once resolved. Scoring is continuous and documented
/// (`PredictionScoring`), never an all-or-nothing "correct/wrong."
struct ChallengeView: View {
    @State var viewModel: ChallengeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingCleanAirDefender = false

    private var backgroundCategory: AQICategory {
        viewModel.recentObservations.first?.category ?? .moderate
    }
    private var backgroundSeverity: Double {
        AQICategory.normalizedSeverity(pm25: viewModel.recentObservations.first?.pm25 ?? 20)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SmogSkylineView(category: backgroundCategory, severity: backgroundSeverity, reduceMotion: reduceMotion, showSkyline: false, showGround: false)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ParticleFieldOverlay(tint: backgroundCategory.color, severity: backgroundSeverity)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.load() }
        .sensoryFeedback(.success, trigger: viewModel.submissionTicks)
        .fullScreenCover(isPresented: $showingCleanAirDefender) {
            CleanAirDefenderContainerView(
                onFinish: { showingCleanAirDefender = false },
                loadForecastSnapshot: { await viewModel.currentForecastSnapshot() }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                VStack(spacing: ACSpacing.md) {
                    LoadingCardSkeleton().frame(height: 220)
                    LoadingCardSkeleton().frame(height: 140)
                }
                .padding()
            }
        case .failed(let kind, let message) where viewModel.challenges.isEmpty:
            ScrollView {
                ACStateView(kind: kind, title: "Couldn't load the Challenge", message: message, actionTitle: "Try Again", action: { Task { await viewModel.load() } })
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
                todaySection

                if viewModel.averageScore != nil || !viewModel.resolvedChallenges.isEmpty {
                    ChallengeStatsRow(
                        averageScore: viewModel.averageScore,
                        streak: viewModel.streak,
                        resolvedCount: viewModel.resolvedChallenges.count
                    )
                }

                if !viewModel.recentObservations.isEmpty {
                    MiniTrendChart(observations: viewModel.recentObservations)
                }

                if !viewModel.resolvedChallenges.isEmpty {
                    SectionHeader(title: "Past reveals", subtitle: "Every resolved prediction, most recent first")
                    ForEach(viewModel.resolvedChallenges) { challenge in
                        ChallengeRevealCard(challenge: challenge)
                    }
                } else {
                    ACStateView(
                        kind: .empty,
                        title: "No reveals yet",
                        message: "Once a prediction resolves, your comparison against AirCast's model will show up here."
                    )
                }
            }
            .padding()
            .padding(.bottom, ACSpacing.xl)
        }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var todaySection: some View {
        if let today = viewModel.todayChallenge {
            SurfaceCard {
                VStack(alignment: .leading, spacing: ACSpacing.sm) {
                    Label(today.isResolved ? "Today's prediction — resolved below" : "Prediction locked in", systemImage: today.isResolved ? "checkmark.seal" : "lock")
                        .font(ACFont.cardTitle())
                        .foregroundStyle(ACColor.textPrimary)
                    Text("You predicted \(Int(today.userPredictionPM25.rounded())) µg/m³ for \(today.challengeDate.formatted(date: .abbreviated, time: .omitted)).\(today.isResolved ? "" : " Check back after it resolves.")")
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                    if !today.isResolved {
                        Text("Predictions lock at midnight local time and can't be edited after that.")
                            .font(ACFont.micro())
                            .foregroundStyle(ACColor.textTertiary)

                        VStack(alignment: .leading, spacing: ACSpacing.xxs) {
                            Button {
                                showingCleanAirDefender = true
                            } label: {
                                Label("Play Clean Air Defender", systemImage: "wind")
                            }
                            .buttonStyle(.acSecondary)
                            Text("Learn what's pushing tomorrow's air up or down.")
                                .font(ACFont.micro())
                                .foregroundStyle(ACColor.textTertiary)
                        }
                        .padding(.top, ACSpacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            SurfaceCard {
                VStack(alignment: .leading, spacing: ACSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Think you can beat the model?")
                            .font(ACFont.cardTitle())
                            .foregroundStyle(ACColor.textPrimary)
                        Text("Predict tomorrow's PM2.5. Score is continuous — closer guesses always score higher, no all-or-nothing.")
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                    }

                    PredictionSliderInput(value: $viewModel.sliderValue)

                    if let error = viewModel.submitErrorMessage {
                        Text(error)
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.danger)
                    }

                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Lock In Prediction")
                        }
                    }
                    .buttonStyle(.acPrimary)
                    .disabled(viewModel.isSubmitting)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("Challenge — with history") {
    ChallengeView(viewModel: ChallengeViewModel(repository: DemoAirQualityRepository(scenario: .moderateRising)))
}
