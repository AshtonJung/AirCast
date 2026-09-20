import SwiftUI

/// Primary call-to-action button style: filled, accent-tinted, haptic on press.
struct ACPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ACFont.cardTitle())
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: ACRadius.md, style: .continuous)
                    .fill(ACColor.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ACMotion.quickSpring, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

/// Secondary button style: outlined, low-emphasis.
struct ACSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ACFont.cardTitle())
            .foregroundStyle(ACColor.accent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: ACRadius.md, style: .continuous)
                    .strokeBorder(ACColor.accent.opacity(0.5), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ACMotion.quickSpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ACPrimaryButtonStyle {
    static var acPrimary: ACPrimaryButtonStyle { ACPrimaryButtonStyle() }
}

extension ButtonStyle where Self == ACSecondaryButtonStyle {
    static var acSecondary: ACSecondaryButtonStyle { ACSecondaryButtonStyle() }
}

#Preview("Buttons") {
    VStack(spacing: ACSpacing.md) {
        Button("Start Prediction Challenge") {}
            .buttonStyle(.acPrimary)
        Button("View Model Lab") {}
            .buttonStyle(.acSecondary)
    }
    .padding()
    .background(ACColor.background)
}
