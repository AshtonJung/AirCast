import SwiftUI

/// A small, tasteful achievement grid — locked badges are dimmed, not
/// hidden, so the full (short, honest) list is always visible rather than
/// implying an endless grind.
struct AchievementGrid: View {
    let achievements: [Achievement]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: ACSpacing.sm) {
                SectionHeader(title: "Achievements")
                LazyVGrid(columns: columns, spacing: ACSpacing.sm) {
                    ForEach(achievements) { achievement in
                        tile(achievement)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tile(_ achievement: Achievement) -> some View {
        VStack(alignment: .leading, spacing: ACSpacing.xxs) {
            Image(systemName: achievement.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? ACColor.accent : ACColor.textTertiary)
            Text(achievement.title)
                .font(ACFont.caption())
                .fontWeight(.semibold)
                .foregroundStyle(achievement.isUnlocked ? ACColor.textPrimary : ACColor.textTertiary)
            Text(achievement.detail)
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textTertiary)
                .lineLimit(2)
        }
        .padding(ACSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ACRadius.sm, style: .continuous)
                .fill(achievement.isUnlocked ? ACColor.accent.opacity(0.1) : ACColor.surfaceSecondary)
        )
        .opacity(achievement.isUnlocked ? 1 : 0.6)
        .tiltInteractive()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title): \(achievement.detail) \(achievement.isUnlocked ? "Unlocked" : "Locked")")
    }
}

#Preview("AchievementGrid") {
    AchievementGrid(achievements: [
        Achievement(id: "1", title: "First Prediction", detail: "Resolve your first prediction.", symbolName: "1.circle", isUnlocked: true),
        Achievement(id: "2", title: "Beat the Model", detail: "Get closer than AirCast.", symbolName: "trophy", isUnlocked: false),
    ])
    .padding()
    .background(ACColor.background)
}
