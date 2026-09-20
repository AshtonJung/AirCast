import SpriteKit

/// The on-screen "Clean Air Blaster" — a fixed nozzle at the bottom of the
/// scene that every water shot visibly fires from. Gives the tap-to-clear
/// mechanic an actual tool (per the work order's original "Clean Air
/// Blaster" naming) instead of reading as an abstract tap-and-vanish —
/// concretely what the "shoot the PM2.5 with water" request asks for.
final class BlasterNode: SKNode {
    private let nozzle: SKShapeNode
    private let glow: SKShapeNode

    override init() {
        glow = SKShapeNode(circleOfRadius: 30)
        glow.fillColor = SKColor(red: 0.42, green: 0.78, blue: 0.95, alpha: 0.25)
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.zPosition = -1

        nozzle = SKShapeNode(path: BlasterNode.nozzlePath())
        nozzle.fillColor = SKColor(red: 0.34, green: 0.68, blue: 0.88, alpha: 0.95)
        nozzle.strokeColor = .white.withAlphaComponent(0.9)
        nozzle.lineWidth = 2
        nozzle.glowWidth = 2

        super.init()
        zPosition = 16
        addChild(glow)
        addChild(nozzle)

        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 1.1),
            SKAction.scale(to: 1.0, duration: 1.1),
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A tightly-timed "kick" — recoil back then snap forward — played every
    /// time a shot is fired, plus a bright muzzle flash at the nozzle tip so
    /// firing reads as a discrete, felt event rather than a passive tap.
    func fire() {
        removeAction(forKey: "recoil")
        let kick = SKAction.sequence([
            SKAction.scale(to: 0.82, duration: 0.035),
            SKAction.scale(to: 1.08, duration: 0.07),
            SKAction.scale(to: 1.0, duration: 0.09),
        ])
        run(kick, withKey: "recoil")

        let flash = SKShapeNode(circleOfRadius: 14)
        flash.position = CGPoint(x: 0, y: 24)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.blendMode = .add
        flash.zPosition = 1
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.8, duration: 0.09),
                SKAction.fadeOut(withDuration: 0.09),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    /// A simple rounded, upward-pointing nozzle silhouette — deliberately a
    /// stylized tool shape, not a realistic weapon (work order §3: no
    /// realistic firearms/military imagery).
    private static func nozzlePath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 30))
        path.addLine(to: CGPoint(x: -15, y: 2))
        path.addQuadCurve(to: CGPoint(x: 15, y: 2), control: CGPoint(x: 0, y: -14))
        path.closeSubpath()
        return path
    }
}
