import SpriteKit

/// A "+75"-style floating score readout that pops up at the hit location and
/// drifts/fades away — the classic arcade "juice" cue that was missing from
/// the first pass (work order §25: "satisfying hits"). Purely decorative:
/// `CleanAirDefenderGameState` remains the single source of truth for score,
/// this node just narrates what the HUD number is about to become.
enum ScorePopupNode {
    static func spawn(in scene: SKScene, at position: CGPoint, points: Int, isBonus: Bool, reduceMotion: Bool) {
        let label = SKLabelNode(text: "+\(points)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = isBonus ? 26 : 20
        label.fontColor = isBonus ? .white : SKColor(white: 1, alpha: 0.95)
        label.position = CGPoint(x: position.x, y: position.y + 12)
        label.zPosition = 25
        label.verticalAlignmentMode = .center
        label.setScale(0.6)
        scene.addChild(label)

        let duration = reduceMotion ? 0.35 : 0.6
        let riseDistance: CGFloat = reduceMotion ? 18 : 34
        let popIn = SKAction.scale(to: 1.0, duration: 0.1)
        popIn.timingMode = .easeOut
        let rise = SKAction.moveBy(x: 0, y: riseDistance, duration: duration)
        rise.timingMode = .easeOut
        let fade = SKAction.sequence([
            SKAction.wait(forDuration: duration * 0.4),
            SKAction.fadeOut(withDuration: duration * 0.6),
        ])
        label.run(SKAction.sequence([
            popIn,
            SKAction.group([rise, fade]),
            SKAction.removeFromParent(),
        ]))
    }
}
