import SpriteKit

/// One-shot "hit" feedback: a translucent splash that expands and fades,
/// plus a few dissolving debris motes — the paintball-style pop specified in
/// work order §7. Every node it spawns removes itself when its action
/// sequence finishes, so nothing is retained (§23: no unbounded/retained nodes).
enum SplashEffectNode {
    static func spawn(in scene: SKScene, at position: CGPoint, color: SKColor, reduceMotion: Bool) {
        // A brief bright core flash at the moment of impact — the "pop"
        // work order §7 asks for — separate from the color splash below so
        // the hit reads instantly even before the splash has expanded.
        let flash = SKShapeNode(circleOfRadius: 10)
        flash.position = position
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.zPosition = 22
        flash.alpha = 0.9
        flash.blendMode = .add
        scene.addChild(flash)
        let flashDuration = reduceMotion ? 0.1 : 0.18
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: reduceMotion ? 1.4 : 2.2, duration: flashDuration),
                SKAction.fadeOut(withDuration: flashDuration),
            ]),
            SKAction.removeFromParent(),
        ]))

        let splash = SKShapeNode(circleOfRadius: 6)
        splash.position = position
        splash.fillColor = color
        splash.strokeColor = .clear
        splash.zPosition = 20
        splash.alpha = 0.85
        scene.addChild(splash)

        let duration = reduceMotion ? 0.15 : 0.35
        let scaleUp = SKAction.scale(to: reduceMotion ? 2.0 : 3.6, duration: duration)
        scaleUp.timingMode = .easeOut
        let fadeOut = SKAction.fadeOut(withDuration: duration)
        splash.run(SKAction.sequence([SKAction.group([scaleUp, fadeOut]), SKAction.removeFromParent()]))

        // A thin expanding ring outlines the splash's edge — a classic
        // paintball-hit read (impact ring) distinct from the filled blob,
        // still a single cheap shape node.
        if !reduceMotion {
            let ring = SKShapeNode(circleOfRadius: 8)
            ring.position = position
            ring.fillColor = .clear
            ring.strokeColor = color.withAlphaComponent(0.7)
            ring.lineWidth = 2
            ring.zPosition = 21
            scene.addChild(ring)
            let ringScale = SKAction.scale(to: 4.2, duration: 0.4)
            ringScale.timingMode = .easeOut
            ring.run(SKAction.sequence([
                SKAction.group([ringScale, SKAction.fadeOut(withDuration: 0.4)]),
                SKAction.removeFromParent(),
            ]))
        }

        // Reduce Motion: keep the calm expanding splash above, skip the
        // extra flying debris motes (work order §16/§7 — simplify splashes,
        // avoid extra screen movement, preserve gameplay clarity).
        guard !reduceMotion else { return }

        let moteCount = 7
        for _ in 0..<moteCount {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            mote.position = position
            mote.fillColor = color.withAlphaComponent(CGFloat.random(in: 0.6...0.95))
            mote.strokeColor = .clear
            mote.zPosition = 19
            scene.addChild(mote)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 24...58)
            let vector = CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance)
            let move = SKAction.move(by: vector, duration: 0.45)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.45)
            let shrink = SKAction.scale(to: 0.3, duration: 0.45)
            mote.run(SKAction.sequence([SKAction.group([move, fade, shrink]), SKAction.removeFromParent()]))
        }
    }
}
