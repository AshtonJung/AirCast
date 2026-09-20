import SwiftUI

/// The base "glass" card surface used throughout AirCast. Combines a
/// translucent material with a subtle border and elevation so cards read as
/// floating above the atmospheric background rather than sitting on a flat sheet.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = ACSpacing.md
    var cornerRadius: CGFloat = ACRadius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ACColor.surface.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ACColor.separator.opacity(0.6), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .acShadow()
    }
}

#Preview("SurfaceCard") {
    ZStack {
        AtmosphericBackground(category: .moderate)
        VStack(spacing: ACSpacing.md) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: ACSpacing.xs) {
                    Text("Tomorrow")
                        .font(ACFont.cardTitle())
                        .foregroundStyle(ACColor.textPrimary)
                    Text("PM2.5 forecast improving slightly.")
                        .font(ACFont.body())
                        .foregroundStyle(ACColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}
