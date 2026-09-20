import SpriteKit

/// A fast blue "water shot" that travels from `BlasterNode` to the tapped
/// PM2.5 cluster, arriving in well under a fifth of a second. This is the
/// visible *cause* of the splash/clear effect that plays on arrival —
/// tapping now reads as "I aimed the blaster and fired," not "I touched a
/// bubble and it vanished," directly answering the request to make clearing
/// feel like shooting water at the pollution rather than an abstract tap.
enum WaterShotNode {
    /// Capped short so the mechanic still feels instantaneous/forgiving
    /// (work order §10) — this is a felt cause-and-effect beat, not a
    /// projectile the player has to lead or time.
    private static func travelDuration(for distance: CGFloat) -> TimeInterval {
        max(0.05, min(0.13, Double(distance) / 2400))
    }

    /// Under Reduce Motion, skip the travel animation entirely and resolve
    /// immediately — the shot is decorative flourish on top of an already-
    /// instant hit, never something gameplay waits on for correctness.
    static func spawn(in scene: SKScene, from start: CGPoint, to end: CGPoint, reduceMotion: Bool, onArrival: @escaping () -> Void) {
        guard !reduceMotion else {
            onArrival()
            return
        }

        let distance = hypot(end.x - start.x, end.y - start.y)
        let duration = travelDuration(for: distance)
        let angle = atan2(end.y - start.y, end.x - start.x) - .pi / 2
        let color = SKColor(red: 0.42, green: 0.78, blue: 0.95, alpha: 0.95)

        // Two-to-three trailing droplets, launched a beat after the lead
        // shot, give the streak visible motion/weight without needing a
        // custom trail-rendering pass.
        for i in 1...2 {
            let trail = SKShapeNode(ellipseOf: CGSize(width: 6, height: 13))
            trail.fillColor = color.withAlphaComponent(0.3)
            trail.strokeColor = .clear
            trail.blendMode = .add
            trail.position = start
            trail.zRotation = angle
            trail.zPosition = 17
            scene.addChild(trail)
            let move = SKAction.move(to: end, duration: duration)
            move.timingMode = .easeIn
            trail.run(SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.018),
                SKAction.group([move, SKAction.fadeOut(withDuration: duration * 0.8)]),
                SKAction.removeFromParent(),
            ]))
        }

        let shot = SKShapeNode(ellipseOf: CGSize(width: 11, height: 24))
        shot.fillColor = color
        shot.strokeColor = .white.withAlphaComponent(0.85)
        shot.lineWidth = 1.5
        shot.glowWidth = 3
        shot.position = start
        shot.zRotation = angle
        shot.zPosition = 18
        shot.blendMode = .add
        scene.addChild(shot)

        let move = SKAction.move(to: end, duration: duration)
        move.timingMode = .easeIn
        shot.run(SKAction.sequence([
            move,
            SKAction.run { onArrival() },
            SKAction.group([
                SKAction.scale(to: 1.6, duration: 0.06),
                SKAction.fadeOut(withDuration: 0.06),
            ]),
            SKAction.removeFromParent(),
        ]))
    }
}
