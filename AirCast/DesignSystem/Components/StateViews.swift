import SwiftUI

/// A single, polished component for every non-happy-path state: empty,
/// error, and offline. Guide rule: these must be "visually complete, not
/// developer placeholders" — so this is illustrated with symbol + motion,
/// not a bare "Error" string.
struct ACStateView: View {
    enum Kind: Equatable {
        case empty
        case error
        case offline
        case stale

        var symbolName: String {
            switch self {
            case .empty: return "tray"
            case .error: return "exclamationmark.triangle"
            case .offline: return "wifi.slash"
            case .stale: return "clock.arrow.circlepath"
            }
        }

        var tint: Color {
            switch self {
            case .empty: return ACColor.textSecondary
            case .error: return ACColor.danger
            case .offline: return ACColor.textSecondary
            case .stale: return ACColor.warning
            }
        }
    }

    let kind: Kind
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: ACSpacing.md) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(kind.tint)
                .symbolEffect(.bounce, value: appeared)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: ACSpacing.xxs) {
                Text(title)
                    .font(ACFont.cardTitle())
                    .foregroundStyle(ACColor.textPrimary)
                Text(message)
                    .font(ACFont.body())
                    .foregroundStyle(ACColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.acSecondary)
                    .frame(maxWidth: 220)
            }
        }
        .padding(ACSpacing.lg)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: ACMotion.quickDuration) : ACMotion.standardSpring) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("StateViews") {
    ScrollView {
        VStack(spacing: ACSpacing.lg) {
            ACStateView(kind: .empty, title: "No predictions yet", message: "Make your first PM2.5 prediction to start your streak.", actionTitle: "Start Challenge", action: {})
            ACStateView(kind: .error, title: "Couldn't load forecast", message: "Something went wrong while fetching the latest data.", actionTitle: "Try Again", action: {})
            ACStateView(kind: .offline, title: "You're offline", message: "Showing the last saved forecast. Switch to Demo Mode to explore without a connection.", actionTitle: "Use Demo Mode", action: {})
            ACStateView(kind: .stale, title: "Data may be out of date", message: "We haven't been able to refresh in a while.")
        }
        .padding()
    }
    .background(ACColor.background)
}
