import SwiftUI

/// Compact stat tiles for the Challenge screen — average score and streak,
/// both computed directly from resolved challenges, never a hard-coded or
/// inflated number.
struct ChallengeStatsRow: View {
    let averageScore: Double?
    let streak: Int
    let resolvedCount: Int

    var body: some View {
        HStack(spacing: ACSpacing.sm) {
            tile(title: "Avg. score", value: averageScore.map { "\(Int($0.rounded()))" } ?? "—", icon: "target")
            tile(title: "Streak", value: "\(streak)\(streak == 1 ? " day" : " days")", icon: "flame")
            tile(title: "Resolved", value: "\(resolvedCount)", icon: "checkmark.circle")
        }
    }

    private func tile(title: String, value: String, icon: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.xxs) {
                Image(systemName: icon)
                    .foregroundStyle(ACColor.accent)
                Text(value)
                    .font(ACFont.numericEmphasis())
                    .foregroundStyle(ACColor.textPrimary)
                Text(title)
                    .font(ACFont.micro())
                    .foregroundStyle(ACColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("ChallengeStatsRow") {
    ChallengeStatsRow(averageScore: 78, streak: 3, resolvedCount: 5)
        .padding()
        .background(ACColor.background)
}
