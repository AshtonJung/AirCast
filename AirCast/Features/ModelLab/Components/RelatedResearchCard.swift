import SwiftUI

/// The "Built from research" narrative: the peer-reviewed-style statistical
/// study that motivated which weather features the forecast model uses —
/// kept visually and textually distinct from the forecast model itself, so
/// it's never mistaken for the same thing.
struct RelatedResearchCard: View {
    let research: RelatedResearch

    @State private var expanded = false

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                Label("Built from research", systemImage: "graduationcap")
                    .font(ACFont.micro())
                    .fontWeight(.semibold)
                    .foregroundStyle(ACColor.accent)

                Text(research.title)
                    .font(ACFont.cardTitle())
                    .foregroundStyle(ACColor.textPrimary)

                Text(research.summary)
                    .font(ACFont.body())
                    .foregroundStyle(ACColor.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Key finding")
                        .font(ACFont.micro())
                        .foregroundStyle(ACColor.textTertiary)
                    Text(research.keyFinding)
                        .font(ACFont.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(ACColor.textPrimary)
                }
                .padding(ACSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: ACRadius.sm, style: .continuous).fill(ACColor.surfaceSecondary))

                Button {
                    withAnimation(ACMotion.quickSpring) { expanded.toggle() }
                } label: {
                    HStack {
                        Text(expanded ? "Hide methodology & limitations" : "Show methodology & limitations")
                        Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .font(ACFont.caption())
                    .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ACColor.accent)

                if expanded {
                    VStack(alignment: .leading, spacing: ACSpacing.xs) {
                        Text(research.methodology)
                            .font(ACFont.caption())
                            .foregroundStyle(ACColor.textSecondary)
                        ForEach(research.limitations, id: \.self) { limitation in
                            HStack(alignment: .top, spacing: ACSpacing.xxs) {
                                Text("•")
                                Text(limitation)
                            }
                            .font(ACFont.micro())
                            .foregroundStyle(ACColor.textTertiary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("RelatedResearchCard") {
    RelatedResearchCard(research: RelatedResearch(
        title: "Post-Peak Atmospheric Removal Conditions and Recovery from PM2.5 Pollution Episodes",
        summary: "Tested whether stronger post-peak wind and precipitation sped up recovery from PM2.5 episodes.",
        keyFinding: "HR 1.199 (95% CI 1.063–1.352, p=0.003)",
        methodology: "Cox proportional-hazards model on 143 episodes.",
        limitations: ["Sensitivity pattern not uniformly robust.", "Wind/precip not individually significant."]
    ))
    .padding()
    .background(ACColor.background)
}
