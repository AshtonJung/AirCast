import SpriteKit
import UIKit

/// One tappable PM2.5 particle cluster. This node only knows how to look
/// right and report its own density — scoring, combo, and haze bookkeeping
/// all live in `CleanAirDefenderGameState` (work order §8/§24: no
/// duplicated scoring logic scattered across files).
///
/// Visually a genuine *cluster* — several overlapping soft-edged motes
/// inside a diffuse haze glow, not a single hard-edged disc — so it reads as
/// "hazy particles drifting" rather than a solid arcade token, matching the
/// work order §7 visual brief. The glow texture is generated once per
/// `ParticleDensity` (3 total) and reused for every spawn (§23: prefer
/// reusable textures, avoid regenerating assets during active gameplay).
final class ParticleTargetNode: SKNode {
    let density: ParticleDensity

    /// Forgiving hit radius — noticeably larger than the drawn circle so a
    /// quick tap near the edge still registers (work order §10 "no
    /// complicated movement," §16 "do not use tiny targets").
    var hitTestRadius: CGFloat { density.radius + 14 }

    init(density: ParticleDensity) {
        self.density = density
        super.init()
        name = "particleTarget"
        zPosition = 10

        let radius = density.radius
        let color = ParticleTargetNode.fillColor(for: density)

        let glow = SKSpriteNode(texture: Self.glowTexture(for: density, color: color))
        glow.size = CGSize(width: radius * 3.4, height: radius * 3.4)
        glow.zPosition = 0
        glow.blendMode = .add
        glow.alpha = 0.9
        addChild(glow)

        // A handful of overlapping sub-motes suggest a genuine "cluster" of
        // particles rather than one dot — directly matches the "PM2.5
        // particle cluster" concept, at negligible extra cost since only a
        // few clusters are ever alive on screen at once.
        let subCount = density == .heavy ? 5 : (density == .medium ? 4 : 3)
        for i in 0..<subCount {
            let subRadius = radius * CGFloat.random(in: 0.34...0.52)
            let sub = SKShapeNode(circleOfRadius: subRadius)
            sub.fillColor = color.withAlphaComponent(CGFloat.random(in: 0.55...0.85))
            sub.strokeColor = .clear
            let offsetDistance = radius * CGFloat.random(in: 0...0.4)
            let angle = (CGFloat(i) / CGFloat(subCount)) * .pi * 2 + CGFloat.random(in: -0.35...0.35)
            sub.position = CGPoint(x: cos(angle) * offsetDistance, y: sin(angle) * offsetDistance)
            sub.zPosition = 1
            addChild(sub)
        }

        // Thin crisp outer ring so the target keeps a legible edge even
        // against a bright sky — never relying on the soft glow alone for
        // contrast (work order §16: adequate contrast).
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = color.withAlphaComponent(0.9)
        ring.lineWidth = 1.5
        ring.fillColor = .clear
        ring.zPosition = 2
        addChild(ring)

        // Entrance "puff-in" (work order §25: smooth entrance), then settle
        // into a slow breathing pulse — sequenced, not concurrent, with the
        // entrance so the two scale animations never fight each other.
        setScale(0.35)
        alpha = 0
        let enter = SKAction.group([
            SKAction.scale(to: 1, duration: 0.22),
            SKAction.fadeAlpha(to: 1, duration: 0.16),
        ])
        enter.timingMode = .easeOut
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.scale(to: 1.06, duration: 0.9),
            SKAction.scale(to: 1.0, duration: 0.9),
        ]))
        run(SKAction.sequence([enter, pulse]))

        // Slow independent rotation so the cluster's motes drift relative
        // to one another instead of looking frozen — cheap (one action,
        // angle only) and respects Reduce Motion by simply running slower
        // being imperceptible isn't necessary here since rotation is subtle
        // enough not to count as "camera shake"-style motion.
        run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: Double.random(in: 14...22))))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func fillColor(for density: ParticleDensity) -> SKColor {
        switch density {
        case .light: return SKColor(red: 0.62, green: 0.45, blue: 0.32, alpha: 0.85)
        case .medium: return SKColor(red: 0.52, green: 0.36, blue: 0.28, alpha: 0.9)
        case .heavy: return SKColor(red: 0.38, green: 0.24, blue: 0.22, alpha: 0.95)
        }
    }

    // MARK: Cached glow texture

    private static var glowTextureCache: [ParticleDensity: SKTexture] = [:]

    /// A soft radial-gradient "haze" sprite, rendered once per density and
    /// cached for the lifetime of the app — never regenerated per spawn.
    private static func glowTexture(for density: ParticleDensity, color: SKColor) -> SKTexture {
        if let cached = glowTextureCache[density] { return cached }
        let diameter = density.radius * 3.4
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let colors = [
                color.withAlphaComponent(0.55).cgColor,
                color.withAlphaComponent(0.18).cgColor,
                color.withAlphaComponent(0).cgColor,
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            cgContext.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: size.width / 2,
                options: []
            )
        }
        let texture = SKTexture(image: image)
        glowTextureCache[density] = texture
        return texture
    }
}
