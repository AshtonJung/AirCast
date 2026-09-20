import SwiftUI
import CoreLocation

/// The full "Why this forecast?" screen: plain-language summary, every
/// ranked driver with an honest contribution bar, a real "what changed since
/// your last refresh" comparison, and the "How AirCast knows" disclosure
/// with a path to Model Lab.
struct WhyView: View {
    @State var viewModel: WhyViewModel
    let modelLabViewModel: ModelLabViewModel
    @EnvironmentObject private var router: TabRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared with `LocationExplorerCard` — tapping its map shifts this
    /// screen's ambient background into the same simulated preview too.
    @State private var exploredCoordinate: CLLocationCoordinate2D?
    @State private var showModelLab = false

    private var backgroundCategory: AQICategory {
        guard let exploredCoordinate else { return viewModel.backgroundCategory }
        return AQICategory.classify(pm25: SimulatedMapReading.pm25(for: exploredCoordinate))
    }
    private var backgroundSeverity: Double {
        guard let exploredCoordinate else { return viewModel.backgroundSeverity }
        return AQICategory.normalizedSeverity(pm25: SimulatedMapReading.pm25(for: exploredCoordinate))
    }

    var body: some View {
        ZStack {
            SmogSkylineView(category: backgroundCategory, severity: backgroundSeverity, reduceMotion: reduceMotion, showSkyline: false, showGround: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ParticleFieldOverlay(tint: backgroundCategory.color, severity: backgroundSeverity)
                .ignoresSafeArea()
            content
        }
        .navigationTitle("Why this forecast?")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showModelLab) {
            ModelLabView(viewModel: modelLabViewModel)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                VStack(spacing: ACSpacing.md) {
                    LoadingCardSkeleton().frame(height: 90)
                    LoadingCardSkeleton().frame(height: 130)
                    LoadingCardSkeleton().frame(height: 130)
                }
                .padding()
            }
        case .failed(let kind, let message) where viewModel.forecast == nil:
            ScrollView {
                ACStateView(kind: kind, title: "Couldn't load explanation", message: message, actionTitle: "Try Again", action: { Task { await viewModel.load() } })
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
                SurfaceCard {
                    Text(viewModel.summarySentence)
                        .font(ACFont.body())
                        .foregroundStyle(ACColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.drivers.isEmpty {
                    ACStateView(kind: .empty, title: "No drivers available", message: "Not enough recent data to explain this forecast yet.")
                } else {
                    VStack(alignment: .leading, spacing: ACSpacing.sm) {
                        SectionHeader(
                            title: "Ranked drivers",
                            subtitle: viewModel.hasComparison ? "Compared to your last refresh" : "Pull to refresh, then check back for what changed"
                        )
                        ForEach(viewModel.drivers) { driver in
                            DriverDetailCard(driver: driver, changeDescription: viewModel.changeDescription(for: driver))
                        }
                    }
                }

                LocationExplorerCard(category: viewModel.backgroundCategory, pm25: viewModel.backgroundPM25, exploredCoordinate: $exploredCoordinate)

                if let modelCard = viewModel.modelCard {
                    HowAirCastKnowsSection(modelCard: modelCard) {
                        showModelLab = true
                    }
                }
            }
            .padding()
            .padding(.bottom, ACSpacing.xl)
        }
        .refreshable { await viewModel.load() }
    }
}

#Preview("WhyView") {
    let repository = DemoAirQualityRepository(scenario: .moderateRising)
    NavigationStack {
        WhyView(viewModel: WhyViewModel(repository: repository), modelLabViewModel: ModelLabViewModel(repository: repository))
    }
    .environmentObject(TabRouter())
}
