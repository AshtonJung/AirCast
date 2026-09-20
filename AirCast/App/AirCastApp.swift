import SwiftUI

@main
struct AirCastApp: App {
    /// The single shared data source for this app launch. Kept as the
    /// concrete type here (only place in the app that needs to be) so
    /// Settings can switch its bundled demo scenario; everywhere else sees
    /// it only through the `AirQualityRepository` protocol. Swapping this
    /// for a live-mode repository is the only change needed to move off
    /// demo data.
    private let repository = DemoAirQualityRepository()

    var body: some Scene {
        WindowGroup {
            AppRootView(
                repository: repository,
                setScenario: { scenario in await repository.setScenario(scenario) },
                getCurrentScenario: { await repository.currentScenario },
                resetDemo: { await repository.resetDemo() }
            )
            .preferredColorScheme(nil) // respect system light/dark
        }
    }
}
