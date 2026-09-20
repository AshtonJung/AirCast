import SwiftUI
import CoreLocation

/// The Forecast tab: an interactive data story, not a static weather table.
/// Drag the chart (or use the day chips) to inspect any observed or forecast
/// point; the summary card, Why strip, and legend all update together.
struct ForecastView: View {
    @State var viewModel: ForecastViewModel
    let whyViewModel: WhyViewModel
    let modelLabViewModel: ModelLabViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared with `LocationExplorerCard` — tapping its map shifts this
    /// screen's ambient background into the same simulated preview too.
    @State private var exploredCoordinate: CLLocationCoordinate2D?

    private var backgroundCategory: AQICategory {
        guard let exploredCoordinate else { return viewModel.backgroundCategory }
        return AQICategory.classify(pm25: SimulatedMapReading.pm25(for: exploredCoordinate))
    }
    private var backgroundSeverity: Double {
        guard let exploredCoordinate else { return viewModel.backgroundSeverity }
        return AQICategory.normalizedSeverity(pm25: SimulatedMapReading.pm25(for: exploredCoordinate))
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
            .navigationTitle("Forecast")
            .navigationDestination(for: WhyDestination.self) { _ in
                WhyView(viewModel: whyViewModel, modelLabViewModel: modelLabViewModel)
            }
        }
        .task { await viewModel.load() }
        .sensoryFeedback(.selection, trigger: viewModel.selectionTicks)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                VStack(spacing: ACSpacing.md) {
                    LoadingCardSkeleton().frame(height: 260)
                    LoadingCardSkeleton().frame(height: 130)
                }
                .padding()
            }
        case .failed(let kind, let message) where viewModel.forecast == nil:
            ScrollView {
                ACStateView(kind: kind, title: "Couldn't load forecast", message: message, actionTitle: "Try Again", action: { Task { await viewModel.load() } })
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
                if let selection = viewModel.selection {
                    ForecastSelectionSummaryCard(selection: selection)
                        .tiltInteractive()
                }

                // No .tiltInteractive() here — the map/street view already
                // handles its own pan/zoom/rotate/pitch; a second drag
                // gesture on top would fight it.
                LocationExplorerCard(category: viewModel.backgroundCategory, pm25: viewModel.backgroundPM25, exploredCoordinate: $exploredCoordinate)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: ACSpacing.sm) {
                        ForecastChart(
                            observations: viewModel.chronologicalObservations,
                            forecastPoints: viewModel.forecastPoints,
                            selection: $viewModel.selection,
                            onSelectionChanged: { date in viewModel.select(closestTo: date) }
                        )
                        ForecastDayChips(points: viewModel.headlinePoints, selection: $viewModel.selection)
                        ForecastLegend(modelVersion: viewModel.modelVersion)
                    }
                }

                VStack(alignment: .leading, spacing: ACSpacing.sm) {
                    WhyDriverStrip(drivers: whyDrivers, onSelect: nil)
                    if !whyDrivers.isEmpty {
                        NavigationLink(value: WhyDestination.detail) {
                            Label("See full explanation", systemImage: "text.magnifyingglass")
                                .font(ACFont.caption())
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(ACColor.accent)
                    }
                }

                if let selection = viewModel.selection, !selection.isObserved {
                    Text("Uncertainty grows the further out the forecast reaches — day 2 and day 3 reuse the model's own prediction as input and weren't separately validated, so they're shown with a confidence label instead of a numeric range.")
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                }
            }
            .padding()
            .padding(.bottom, ACSpacing.xl)
        }
        .refreshable { await viewModel.load() }
    }

    /// Drivers only make sense to show when the user is looking at a forecast
    /// point (they explain *that* prediction); an observed point has no
    /// "why" beyond "that's what was measured."
    private var whyDrivers: [ExplanationDriver] {
        guard let selection = viewModel.selection, !selection.isObserved else { return [] }
        return viewModel.drivers
    }
}

/// A trivial marker used with `navigationDestination(for:)` to push the full
/// Why screen from Forecast without needing to pass driver data through the
/// navigation value itself (the pushed `WhyView` reads from its own view model).
enum WhyDestination: Hashable {
    case detail
}

#Preview("Forecast — loaded") {
    let repository = DemoAirQualityRepository(scenario: .moderateRising)
    ForecastView(viewModel: ForecastViewModel(repository: repository), whyViewModel: WhyViewModel(repository: repository), modelLabViewModel: ModelLabViewModel(repository: repository))
        .environmentObject(TabRouter())
}

#Preview("Forecast — low confidence") {
    let repository = DemoAirQualityRepository(scenario: .unhealthyLowConfidence)
    ForecastView(viewModel: ForecastViewModel(repository: repository), whyViewModel: WhyViewModel(repository: repository), modelLabViewModel: ModelLabViewModel(repository: repository))
        .environmentObject(TabRouter())
}
