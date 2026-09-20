import SwiftUI

/// The app's four primary destinations. A single enum keeps tab selection
/// state typed and makes deep-linking (e.g. Home's Challenge CTA jumping to
/// the Challenge tab) straightforward later.
enum AppTab: Hashable {
    case home
    case forecast
    case challenge
    case profile
}

/// Root navigation shell: a 4-tab structure hosting Home, Forecast,
/// Challenge, and Profile/More. This is intentionally the only place in the
/// app that owns top-level navigation state — and the only place that knows
/// how to switch the bundled demo scenario and refresh every tab afterward.
struct AppRootView: View {
    @StateObject private var router = TabRouter()
    @State private var homeViewModel: HomeViewModel
    @State private var forecastViewModel: ForecastViewModel
    @State private var whyViewModel: WhyViewModel
    @State private var challengeViewModel: ChallengeViewModel
    @State private var modelLabViewModel: ModelLabViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var currentScenario: DemoScenario = .cleanAirImproving

    private let setScenario: (DemoScenario) async -> Void
    private let getCurrentScenario: () async -> DemoScenario
    private let resetDemo: () async -> Void

    init(
        repository: AirQualityRepository,
        setScenario: @escaping (DemoScenario) async -> Void,
        getCurrentScenario: @escaping () async -> DemoScenario,
        resetDemo: @escaping () async -> Void
    ) {
        _homeViewModel = State(initialValue: HomeViewModel(repository: repository))
        _forecastViewModel = State(initialValue: ForecastViewModel(repository: repository))
        _whyViewModel = State(initialValue: WhyViewModel(repository: repository))
        _challengeViewModel = State(initialValue: ChallengeViewModel(repository: repository))
        _modelLabViewModel = State(initialValue: ModelLabViewModel(repository: repository))
        _profileViewModel = State(initialValue: ProfileViewModel(repository: repository))
        self.setScenario = setScenario
        self.getCurrentScenario = getCurrentScenario
        self.resetDemo = resetDemo
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            ForecastView(viewModel: forecastViewModel, whyViewModel: whyViewModel, modelLabViewModel: modelLabViewModel)
                .tabItem { Label("Forecast", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.forecast)

            ChallengeView(viewModel: challengeViewModel)
                .tabItem { Label("Challenge", systemImage: "target") }
                .tag(AppTab.challenge)

            ProfileView(
                viewModel: profileViewModel,
                modelLabViewModel: modelLabViewModel,
                currentScenario: currentScenario,
                onSelectScenario: { scenario in
                    await setScenario(scenario)
                    currentScenario = scenario
                    await refreshAll()
                },
                onResetDemo: {
                    await resetDemo()
                    currentScenario = await getCurrentScenario()
                    await refreshAll()
                }
            )
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(ACColor.accent)
        .environmentObject(router)
        .task { currentScenario = await getCurrentScenario() }
    }

    /// Reloads every tab's data after the demo scenario changes underneath
    /// them — without this, switching scenarios in Settings would silently
    /// leave stale data on screen until the user happened to pull-to-refresh.
    private func refreshAll() async {
        async let home: Void = homeViewModel.load()
        async let forecast: Void = forecastViewModel.load()
        async let why: Void = whyViewModel.load()
        async let challenge: Void = challengeViewModel.load()
        async let profile: Void = profileViewModel.load()
        _ = await (home, forecast, why, challenge, profile)
    }
}

#Preview("AppRootView") {
    let repository = DemoAirQualityRepository()
    AppRootView(
        repository: repository,
        setScenario: { await repository.setScenario($0) },
        getCurrentScenario: { await repository.currentScenario },
        resetDemo: { await repository.resetDemo() }
    )
}
