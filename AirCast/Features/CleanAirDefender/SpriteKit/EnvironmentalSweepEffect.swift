import SpriteKit

/// A brief full-scene "whoosh" that plays when a wind or rain boost is
/// activated — visually distinct per kind (horizontal gusts vs. vertical
/// streaks), tying the abstract "particles cleared" effect to something
/// that reads as wind/rain specifically, not just a generic screen flash
/// (work order §9 B/C, §25 "satisfying interaction").
///
/// Skipped entirely under Reduce Motion — this is decorative screen-wide
/// motion on top of the already-required particle sweep/wash effect, not
/// load-bearing for understanding what happened (the callout banner text
/// carries that).
enum EnvironmentalSweepEffect {
    static func spawn(in scene: SKScene, kind: EnvironmentalBoostKind, reduceMotion: Bool) {
        guard !reduceMotion else { return }
        switch kind {
        case .wind: spawnWindGusts(in: scene)
        case .rain: spawnRainStreaks(in: scene)
        }
    }

    private static func spawnWindGusts(in scene: SKScene) {
        let tint = SKColor(red: 0.36, green: 0.70, blue: 0.80, alpha: 1)
        let barCount = 4
        for i in 0..<barCount {
            let bar = SKShapeNode(rectOf: CGSize(width: scene.size.width * 1.3, height: 3))
            bar.fillColor = tint.withAlphaComponent(0.35)
            bar.strokeColor = .clear
            bar.zPosition = 15
            let y = scene.size.height * CGFloat.random(in: 0.15...0.85)
            bar.position = CGPoint(x: -scene.size.width, y: y)
            bar.blendMode = .add
            scene.addChild(bar)

            let delay = Double(i) * 0.05
            let move = SKAction.moveTo(x: scene.size.width * 1.3, duration: 0.5)
            move.timingMode = .easeIn
            bar.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([move, SKAction.fadeOut(withDuration: 0.5)]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    private static func spawnRainStreaks(in scene: SKScene) {
        let tint = SKColor(red: 0.34, green: 0.52, blue: 0.88, alpha: 1)
        let streakCount = 8
        for _ in 0..<streakCount {
            let streak = SKShapeNode(rectOf: CGSize(width: 2.5, height: 46))
            streak.fillColor = tint.withAlphaComponent(0.5)
            streak.strokeColor = .clear
            streak.zPosition = 15
            streak.blendMode = .add
            let x = CGFloat.random(in: 0...scene.size.width) - scene.size.width / 2
            let startY = scene.size.height + CGFloat.random(in: 0...200)
            streak.position = CGPoint(x: x, y: startY)
            scene.addChild(streak)

            let fall = SKAction.moveBy(x: -20, y: -(scene.size.height + 260), duration: Double.random(in: 0.35...0.55))
            fall.timingMode = .easeIn
            streak.run(SKAction.sequence([
                SKAction.group([fall, SKAction.fadeOut(withDuration: 0.5)]),
                SKAction.removeFromParent(),
            ]))
        }
    }
}
