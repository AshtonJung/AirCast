import SwiftUI

/// Short educational pop-up shown after the player interacts with a wind or
/// rain boost — the "user learns what the factor does" requirement from
/// work order Milestone 3's acceptance criteria. Icon + title + text carry
/// the positive/negative meaning together, not color alone (§16).
struct GameCalloutBannerView: View {
    let callout: GameCallout

    private var iconName: String {
        switch callout.tone {
        case .positive: return "checkmark.circle.fill"
        case .negative: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch callout.tone {
        case .positive: return ACColor.positive
        case .negative: return ACColor.danger
        case .info: return ACColor.accent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: ACSpacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(callout.title)
                    .font(ACFont.cardTitle())
                    .foregroundStyle(.white)
                Text(callout.message)
                    .font(ACFont.caption())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(ACSpacing.sm)
        .frame(maxWidth: 320, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ACRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Callout — Positive") {
    ZStack {
        Color.black
        GameCalloutBannerView(callout: EnvironmentalBoostKind.wind.activationCallout)
    }
}

#Preview("Callout — Negative") {
    ZStack {
        Color.black
        GameCalloutBannerView(callout: EnvironmentalBoostKind.wind.incorrectHitCallout(deducted: 25))
    }
}

#Preview("Callout — Info (round intro)") {
    ZStack {
        Color.black
        GameCalloutBannerView(callout: GameCallout(
            title: "TODAY'S PERSISTENCE",
            message: "28 µg/m³ of today's PM2.5 carries into tomorrow's forecast unless wind and rain remove it.",
            tone: .info
        ))
    }
}
