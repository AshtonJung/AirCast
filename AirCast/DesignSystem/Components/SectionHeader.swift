import SwiftUI

/// Standard section header used above groups of cards ("Forecast", "Why this
/// forecast?", "Model Lab"). Optional trailing action for "See all" style links.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingActionTitle: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ACFont.sectionHeader())
                    .foregroundStyle(ACColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                }
            }
            Spacer()
            if let trailingActionTitle, let trailingAction {
                Button(action: trailingAction) {
                    Text(trailingActionTitle)
                        .font(ACFont.caption())
                        .fontWeight(.semibold)
                }
                .foregroundStyle(ACColor.accent)
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}

#Preview("SectionHeader") {
    VStack(spacing: ACSpacing.md) {
        SectionHeader(title: "Forecast", subtitle: "Next 48 hours")
        SectionHeader(title: "Why this forecast?", trailingActionTitle: "Model Lab", trailingAction: {})
    }
    .padding()
    .background(ACColor.background)
}
