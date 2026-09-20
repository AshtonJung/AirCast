import SpriteKit
import UIKit

/// A tappable/drag-able wind or rain boost.
///
/// Deliberately a rounded-square badge with an SF Symbol icon rather than a
/// circle like `ParticleTargetNode` — harmful vs. helpful targets must be
/// visually distinguishable "not color-only" (work order Milestone 3
/// acceptance criteria), so shape + icon carry the distinction, not just tint.
final class EnvironmentalBoostNode: SKNode {
    let kind: EnvironmentalBoostKind
    private let radius: CGFloat = 30

    /// Forgiving hit radius, matching `ParticleTargetNode`'s generous touch
    /// area (work order §16: no tiny targets).
    var hitTestRadius: CGFloat { radius + 16 }

    init(kind: EnvironmentalBoostKind) {
        self.kind = kind
        super.init()

        let tint = EnvironmentalBoostNode.tint(for: kind)

        // A soft breathing halo behind the badge — reads as "collect me,"
        // distinct from `ParticleTargetNode`'s hazy cluster glow (which
        // reads as "clear me") without relying on color alone (work order
        // §16: harmful vs. helpful must be visually distinguishable, not
        // just by tint).
        let halo = SKShapeNode(circleOfRadius: radius * 1.35)
        halo.fillColor = tint.withAlphaComponent(0.28)
        halo.strokeColor = .clear
        halo.zPosition = -1
        halo.blendMode = .add
        addChild(halo)
        halo.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.18, duration: 1.1),
            SKAction.scale(to: 1.0, duration: 1.1),
        ])))

        let badge = SKShapeNode(rectOf: CGSize(width: radius * 1.9, height: radius * 1.9), cornerRadius: 12)
        badge.fillColor = tint.withAlphaComponent(0.88)
        badge.strokeColor = .white
        badge.lineWidth = 2
        badge.glowWidth = 3
        addChild(badge)

        if let texture = Self.iconTexture(for: kind) {
            let icon = SKSpriteNode(texture: texture)
            icon.size = CGSize(width: radius, height: radius)
            icon.zPosition = 1
            addChild(icon)
        }

        name = "environmentalBoost"
        zPosition = 10

        // Entrance "puff-in" matching `ParticleTargetNode`'s, then the
        // existing badge pulse — sequenced so they never fight each other.
        setScale(0.4)
        alpha = 0
        let enter = SKAction.group([
            SKAction.scale(to: 1, duration: 0.22),
            SKAction.fadeAlpha(to: 1, duration: 0.16),
        ])
        enter.timingMode = .easeOut
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.7),
            SKAction.scale(to: 1.0, duration: 0.7),
        ]))
        run(SKAction.sequence([enter, pulse]))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func tint(for kind: EnvironmentalBoostKind) -> SKColor {
        switch kind {
        case .wind: return SKColor(red: 0.36, green: 0.70, blue: 0.80, alpha: 1)
        case .rain: return SKColor(red: 0.34, green: 0.52, blue: 0.88, alpha: 1)
        }
    }

    // MARK: Cached icon texture

    /// Rendered once per `EnvironmentalBoostKind` (2 total, not 3 like
    /// `ParticleTargetNode.glowTextureCache` since there's no per-color
    /// variation here) and reused for every spawn — a boost appears roughly
    /// every 5–10s for the whole round, so re-rendering the same SF Symbol
    /// into a fresh `UIImage`/`SKTexture` on every spawn was avoidable,
    /// repeated work (work order §23: "prefer reusable textures").
    private static var iconTextureCache: [EnvironmentalBoostKind: SKTexture] = [:]

    private static func iconTexture(for kind: EnvironmentalBoostKind) -> SKTexture? {
        if let cached = iconTextureCache[kind] { return cached }
        guard let image = UIImage(systemName: kind.symbolName)?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
            return nil
        }
        let texture = SKTexture(image: image)
        iconTextureCache[kind] = texture
        return texture
    }
}
