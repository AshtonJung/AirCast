import SwiftUI

/// A shimmering placeholder block used while content loads. Communicates
/// "something is coming" rather than a blank screen or spinner-only state.
struct LoadingSkeleton: View {
    var cornerRadius: CGFloat = ACRadius.md
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ACColor.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, ACColor.textPrimary.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerPhase * 220)
                    .opacity(reduceMotion ? 0 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
            .accessibilityHidden(true)
    }
}

/// A representative card-shaped skeleton, ready to drop into a loading state.
struct LoadingCardSkeleton: View {
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                LoadingSkeleton().frame(width: 120, height: 14)
                LoadingSkeleton().frame(width: 180, height: 28)
                LoadingSkeleton().frame(height: 12)
            }
        }
    }
}

#Preview("LoadingSkeleton") {
    VStack(spacing: ACSpacing.md) {
        LoadingCardSkeleton()
        LoadingCardSkeleton()
    }
    .padding()
    .background(ACColor.background)
}
