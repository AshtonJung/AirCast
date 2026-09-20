import SwiftUI
import CoreLocation

/// The cinematic Home screen — the first thing a CAC judge sees. Within
/// three seconds it must communicate: current air quality, tomorrow's
/// forecast, whether things are improving or worsening, and the top driver.
struct HomeView: View {
    @State var viewModel: HomeViewModel
    @EnvironmentObject private var router: TabRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Set the moment the user taps a point on `LocationExplorerCard`'s map
    /// — shared (via binding) with that card so a tap there drives the
    /// hero and ambient background here too, not just the map's own pin.
    @State private var exploredCoordinate: CLLocationCoordinate2D?

    /// The hero's simulated-preview override, or nil when showing the real
    /// station reading.
    private var exploringHero: (pm25: Double, category: AQICategory)? {
        guard let exploredCoordinate else { return nil }
        let pm25 = SimulatedMapReading.pm25(for: exploredCoordinate)
        return (pm25: pm25, category: AQICategory.classify(pm25: pm25))
    }

    private var backgroundCategory: AQICategory {
        exploringHero?.category ?? viewModel.currentObservation?.category ?? .moderate
    }
    private var backgroundSeverity: Double {
        let pm25 = exploringHero?.pm25 ?? viewModel.currentObservation?.pm25 ?? 20
        return AQICategory.normalizedSeverity(pm25: pm25)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SmogSkylineView(
                    category: backgroundCategory,
                    severity: backgroundSeverity,
                    reduceMotion: reduceMotion,
                    showSkyline: false,
                    showGround: false
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)
                ParticleFieldOverlay(tint: backgroundCategory.color, severity: backgroundSeverity)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle("AirCast")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.load() }
        .sensoryFeedback(.success, trigger: viewModel.refreshTicks)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            loadingSkeleton
        case .failed(let kind, let message) where viewModel.currentObservation == nil:
            ScrollView {
                ACStateView(
                    kind: kind,
                    title: title(for: kind),
                    message: message,
                    actionTitle: "Try Again",
                    action: { Task { await viewModel.load() } }
                )
                .padding(.top, ACSpacing.xxl)
                .padding()
            }
        default:
            loadedContent
        }
    }

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: ACSpacing.md) {
                LoadingCardSkeleton().frame(height: 150)
                LoadingCardSkeleton().frame(height: 120)
                LoadingCardSkeleton().frame(height: 110)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if let observation = viewModel.currentObservation {
            ScrollView {
                VStack(alignment: .leading, spacing: ACSpacing.md) {
                    if viewModel.readsAsOffline {
                        ACOfflineBanner()
                    }

                    HeroCard(observation: observation, trend: viewModel.trend, exploring: exploringHero)

                    // No .tiltInteractive() here — the map/street view has
                    // its own native pan/zoom/rotate/pitch gestures, and a
                    // second SwiftUI drag gesture on top would fight it.
                    LocationExplorerCard(category: observation.category, pm25: observation.pm25, exploredCoordinate: $exploredCoordinate)

                    if let tomorrow = viewModel.tomorrowForecast {
                        TomorrowForecastCard(point: tomorrow)
                    }

                    WhyDriverStrip(drivers: viewModel.drivers) {
                        router.selectedTab = .forecast
                    }

                    MiniTrendChart(observations: viewModel.recentObservations) {
                        router.selectedTab = .forecast
                    }

                    ChallengeCTACard {
                        router.selectedTab = .challenge
                    }
                }
                .padding()
                .padding(.bottom, ACSpacing.xl)
            }
            .refreshable { await viewModel.load() }
        }
    }

    private func title(for kind: ACStateView.Kind) -> String {
        switch kind {
        case .empty: return "No data yet"
        case .error: return "Couldn't load AirCast"
        case .offline: return "You're offline"
        case .stale: return "Data may be out of date"
        }
    }
}

/// Compact inline banner shown atop Home content (not a full-screen
/// replacement — there's still last-known data to show) when the freshest
/// observation is old enough to read as offline rather than merely stale.
private struct ACOfflineBanner: View {
    var body: some View {
        HStack(spacing: ACSpacing.xs) {
            Image(systemName: "wifi.slash")
            Text("Showing the last saved data. Reconnect to refresh.")
                .font(ACFont.caption())
        }
        .foregroundStyle(ACColor.textSecondary)
        .padding(.horizontal, ACSpacing.sm)
        .padding(.vertical, ACSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule().fill(ACColor.surfaceSecondary)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Home — good air") {
    HomeView(viewModel: HomeViewModel(repository: DemoAirQualityRepository(scenario: .cleanAirImproving)))
        .environmentObject(TabRouter())
}

#Preview("Home — hazardous, low confidence") {
    HomeView(viewModel: HomeViewModel(repository: DemoAirQualityRepository(scenario: .unhealthyLowConfidence)))
        .environmentObject(TabRouter())
}

#Preview("Home — stale / offline") {
    HomeView(viewModel: HomeViewModel(repository: DemoAirQualityRepository(scenario: .staleOffline)))
        .environmentObject(TabRouter())
}
