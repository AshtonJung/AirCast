import SwiftUI

/// Appearance, demo/live data mode, data sources, privacy, model
/// limitations, and the project story — everything the guide's Settings/
/// About rule asks for, without adding accounts, notifications that don't
/// exist yet, or anything else out of scope.
struct SettingsView: View {
    let modelCard: ModelCard?
    let currentScenario: DemoScenario
    let onSelectScenario: (DemoScenario) async -> Void
    let onResetDemo: () async -> Void

    @AppStorage("ac.appearance") private var appearanceRaw: String = Appearance.system.rawValue
    @State private var isSwitchingScenario = false
    @State private var isResetting = false
    @State private var showResetConfirmation = false

    private enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Demo scenario", selection: Binding<DemoScenario>(
                    get: { currentScenario },
                    set: { newValue in
                        isSwitchingScenario = true
                        Task {
                            await onSelectScenario(newValue)
                            isSwitchingScenario = false
                        }
                    }
                )) {
                    ForEach(DemoScenario.allCases) { scenario in
                        Text(scenario.label).tag(scenario)
                    }
                }
                if isSwitchingScenario {
                    HStack(spacing: ACSpacing.xs) {
                        ProgressView()
                        Text("Switching scenario…")
                    }
                    .font(ACFont.caption())
                    .foregroundStyle(ACColor.textSecondary)
                }
            } header: {
                Text("Data mode")
            } footer: {
                Text("AirCast runs fully offline on bundled, deterministic demo scenarios so the whole app — including the Prediction Challenge and Model Lab — always works without a network connection. This picker is for exploring/judging different conditions; it is not a live data feed.")
            }

            Section("Data sources & acknowledgments") {
                if let card = modelCard {
                    Text(card.dataset.sourceName)
                        .font(ACFont.caption())
                }
                Text("Apple Maps (satellite imagery, Look Around street-level panoramas)")
                    .font(ACFont.caption())
                Text("JEI PM2.5 Episode-Recovery study (Cox proportional-hazards research) — see Model Lab")
                    .font(ACFont.caption())
            }

            Section("Model limitations") {
                if let card = modelCard, let firstLimitation = card.limitations.first {
                    Text(firstLimitation)
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                }
                Text("Full evaluation, diagnostics, and every limitation are in Model Lab.")
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textTertiary)
            }

            Section("Privacy") {
                Text("All predictions, scores, and achievements are stored locally on this device only. AirCast has no accounts, no sign-in, no social features, and does not transmit personal data anywhere.")
                    .font(ACFont.caption())
                    .foregroundStyle(ACColor.textSecondary)
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        if isResetting {
                            ProgressView()
                        } else {
                            Text("Reset Demo")
                        }
                        Spacer()
                    }
                }
                .disabled(isResetting)
                .confirmationDialog(
                    "Reset the demo?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset Demo", role: .destructive) {
                        isResetting = true
                        Task {
                            await onResetDemo()
                            isResetting = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Returns the scenario to \"Clean air, improving\" and clears any prediction you've submitted today. Doesn't affect the resolved historical example.")
                }
            } footer: {
                Text("Use this before handing the app to a judge for a clean, repeatable starting point.")
            }

            Section("About AirCast") {
                Text("AirCast is a student research and engineering project built for the Congressional App Challenge, combining a real statistical forecast model with an interactive, explorable interface. It is not a substitute for official air-quality guidance from environmental agencies.")
                    .font(ACFont.caption())
                    .foregroundStyle(ACColor.textSecondary)
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0 (CAC submission)")
                        .foregroundStyle(ACColor.textSecondary)
                }
                .font(ACFont.caption())
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("SettingsView") {
    NavigationStack {
        SettingsView(modelCard: nil, currentScenario: .cleanAirImproving, onSelectScenario: { _ in }, onResetDemo: {})
    }
}
