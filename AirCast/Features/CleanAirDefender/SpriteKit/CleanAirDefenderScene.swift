import SpriteKit
import UIKit

/// The 30–45 second Clean Air Defender round.
///
/// PM2.5 particle clusters (tap-to-clear) and wind/rain boosts (drag-through
/// to activate) both live here, with score/combo/haze bookkeeping in
/// `CleanAirDefenderGameState`. Every knob this scene reads (spawn rate,
/// heavy-particle odds, wind/rain cadence) comes from `GameScenario`, which
/// `GameScenarioMapper` derives from real forecast data — this scene itself
/// has no idea whether that came from a live forecast or the `.standard` fallback.
final class CleanAirDefenderScene: SKScene {
    private static let dragActivationThreshold: CGFloat = 20

    private let scenario: GameScenario
    private let state: CleanAirDefenderGameState
    /// `var`, not `let`: the initial value comes from `UIAccessibility.isReduceMotionEnabled`
    /// at scene construction, but the player can toggle Reduce Motion mid-round
    /// (Control Center / Accessibility Shortcut) — `setReduceMotion(_:)`,
    /// called from `CleanAirDefenderGameView`'s `.onChange(of:)` on the live
    /// `@Environment(\.accessibilityReduceMotion)`, keeps this in sync so
    /// water shots/splashes/sweeps don't keep animating at full motion after
    /// the player has just turned it off (or vice versa).
    private var reduceMotion: Bool
    /// Nil when sound is disabled (Entry screen toggle) or the platform
    /// couldn't build an audio format — every call site already tolerates
    /// this the same way it tolerates a disabled player (sound is
    /// additive-only, never load-bearing; work order §16/§17).
    private let soundPlayer: GameSoundPlayer?
    /// The visible "Clean Air Blaster" every water shot fires from —
    /// created once and kept for the whole round rather than per-shot.
    private let blasterNode = BlasterNode()

    private var activeParticles: [ParticleTargetNode] = []
    private var activeBoosts: [EnvironmentalBoostNode] = []
    private var lastUpdateTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var timeSinceLastSpawn: TimeInterval = 0
    private var nextSpawnInterval: TimeInterval = 0
    private var timeSinceLastBoostSpawn: TimeInterval = 0
    private var nextBoostSpawnInterval: TimeInterval = 6.5
    private var hasFinished = false

    /// Touch-down bookkeeping used only to disambiguate a boost tap
    /// (mistake) from a boost drag (correct activation) — see
    /// `touchesEnded`. Particles clear instantly on `touchesBegan` and never
    /// use this.
    private var touchStartLocation: CGPoint?
    private var touchStartBoost: EnvironmentalBoostNode?

    init(scenario: GameScenario, state: CleanAirDefenderGameState, reduceMotion: Bool, soundPlayer: GameSoundPlayer?) {
        self.scenario = scenario
        self.state = state
        self.reduceMotion = reduceMotion
        self.soundPlayer = soundPlayer
        super.init(size: CGSize(width: 390, height: 700))
        scaleMode = .resizeFill
        // Transparent so `CleanAirDefenderGameView`'s `SmogSkylineView`
        // backdrop (the same live sky/fog effect used elsewhere in AirCast)
        // shows through behind gameplay, instead of a flat solid color.
        backgroundColor = .clear
        // Origin at bottom-center: makes "spawn near the top, fall toward
        // the bottom" positioning read naturally below.
        anchorPoint = CGPoint(x: 0.5, y: 0)
        nextSpawnInterval = spawnInterval()
        nextBoostSpawnInterval = nextBoostInterval()

        blasterNode.position = CGPoint(x: 0, y: 30)
        addChild(blasterNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Spawning

    private func spawnInterval() -> TimeInterval {
        let base = 1.0 / max(scenario.particleSpawnRate, 0.1)
        return TimeInterval.random(in: base * 0.6...base * 1.3)
    }

    private func spawnParticle() {
        let isHeavy = Double.random(in: 0...1) < scenario.heavyParticleProbability
        let density: ParticleDensity = isHeavy ? .heavy : (Bool.random() ? .medium : .light)
        let node = ParticleTargetNode(density: density)

        let minX = -size.width / 2 + node.hitTestRadius
        let maxX = size.width / 2 - node.hitTestRadius
        let x = maxX > minX ? CGFloat.random(in: minX...maxX) : 0
        node.position = CGPoint(x: x, y: size.height + node.hitTestRadius)
        addChild(node)
        activeParticles.append(node)

        let travel = size.height + node.hitTestRadius * 2
        let fallDuration = max(2.6, TimeInterval(travel / (90 * density.speedMultiplier)))
        let fall = SKAction.moveTo(y: -node.hitTestRadius, duration: fallDuration)
        let expire = SKAction.run { [weak self, weak node] in
            guard let node else { return }
            self?.expire(node)
        }
        node.run(SKAction.sequence([fall, expire]))
    }

    private func expire(_ node: ParticleTargetNode) {
        guard activeParticles.contains(where: { $0 === node }) else { return }
        activeParticles.removeAll { $0 === node }
        node.removeFromParent()
        state.registerMissedParticle()
    }

    /// Average seconds between boost spawns. Higher combined wind+rain
    /// frequency (from `GameScenario`, ultimately from the forecast's
    /// driver contributions) means boosts appear more often overall — the
    /// mechanic shows up more when it's more relevant to teach.
    private func nextBoostInterval() -> TimeInterval {
        let combined = max(scenario.windBoostFrequency + scenario.rainBoostFrequency, 0.2)
        let base = 6.5 / combined
        return TimeInterval.random(in: base * 0.8...base * 1.2)
    }

    private func spawnBoost() {
        let total = scenario.windBoostFrequency + scenario.rainBoostFrequency
        let windShare = total > 0 ? scenario.windBoostFrequency / total : 0.5
        let kind: EnvironmentalBoostKind = Double.random(in: 0...1) < windShare ? .wind : .rain
        let node = EnvironmentalBoostNode(kind: kind)

        let minX = -size.width / 2 + node.hitTestRadius
        let maxX = size.width / 2 - node.hitTestRadius
        let x = maxX > minX ? CGFloat.random(in: minX...maxX) : 0
        node.position = CGPoint(x: x, y: size.height + node.hitTestRadius)
        addChild(node)
        activeBoosts.append(node)

        let fall = SKAction.moveTo(y: -node.hitTestRadius, duration: 4.4)
        let expire = SKAction.run { [weak self, weak node] in
            guard let node else { return }
            self?.expireBoost(node)
        }
        node.run(SKAction.sequence([fall, expire]))
    }

    private func expireBoost(_ node: EnvironmentalBoostNode) {
        guard activeBoosts.contains(where: { $0 === node }) else { return }
        activeBoosts.removeAll { $0 === node }
        node.removeFromParent()
        // Letting a boost pass unclaimed is neutral — "protect it" doesn't
        // mean "you must always catch it" (work order §11: avoid highly
        // punishing mechanics).
    }

    // MARK: Update loop

    override func update(_ currentTime: TimeInterval) {
        guard !hasFinished, !isPaused else {
            lastUpdateTime = 0
            return
        }
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        // Clamp so resuming from background/pause never dumps a huge delta
        // (e.g. a spawn/timer jump) into a single frame.
        let delta = min(currentTime - lastUpdateTime, 0.2)
        lastUpdateTime = currentTime
        elapsed += delta
        timeSinceLastSpawn += delta
        timeSinceLastBoostSpawn += delta

        if timeSinceLastSpawn >= nextSpawnInterval {
            spawnParticle()
            timeSinceLastSpawn = 0
            nextSpawnInterval = spawnInterval()
        }

        if timeSinceLastBoostSpawn >= nextBoostSpawnInterval {
            spawnBoost()
            timeSinceLastBoostSpawn = 0
            nextBoostSpawnInterval = nextBoostInterval()
        }

        let remaining = scenario.duration - elapsed
        state.tick(remaining: remaining)
        state.expireCalloutIfNeeded(elapsed: elapsed)

        if remaining <= 0 {
            finishRound()
        }
    }

    private func finishRound() {
        guard !hasFinished else { return }
        hasFinished = true
        for node in activeParticles { node.removeAllActions() }
        activeParticles.removeAll()
        for node in activeBoosts { node.removeAllActions() }
        activeBoosts.removeAll()
        state.completeRound()
        soundPlayer?.play(.roundComplete)
    }

    // MARK: Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !hasFinished, !isPaused else { return }
        let location = touch.location(in: self)
        touchStartLocation = location
        touchStartBoost = nil

        if let particle = nearestParticle(to: location) {
            // Fires a visible water shot from the blaster to the target —
            // the shot travels in well under 0.15s, so this still reads as
            // an immediate, forgiving hit (work order §7/§10), but now with
            // a felt cause: you aimed the blaster and fired, rather than
            // the cluster simply vanishing on touch.
            fireAtParticle(particle)
            return
        }

        touchStartBoost = nearestBoost(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            touchStartLocation = nil
            touchStartBoost = nil
        }
        guard let touch = touches.first, !hasFinished, !isPaused,
              let boost = touchStartBoost, let start = touchStartLocation else { return }

        let end = touch.location(in: self)
        let dragDistance = hypot(end.x - start.x, end.y - start.y)
        if dragDistance >= Self.dragActivationThreshold {
            activateBoost(boost)
        } else {
            strikeBoostIncorrectly(boost)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartLocation = nil
        touchStartBoost = nil
    }

    /// Distance-based hit testing (rather than exact path containment) so
    /// the tappable area is the generous `hitTestRadius`, not the drawn
    /// shape — forgiving touch areas per work order §10/§16.
    private func nearestParticle(to point: CGPoint) -> ParticleTargetNode? {
        activeParticles
            .filter { hypot($0.position.x - point.x, $0.position.y - point.y) <= $0.hitTestRadius }
            .min { hypot($0.position.x - point.x, $0.position.y - point.y) < hypot($1.position.x - point.x, $1.position.y - point.y) }
    }

    private func nearestBoost(to point: CGPoint) -> EnvironmentalBoostNode? {
        activeBoosts
            .filter { hypot($0.position.x - point.x, $0.position.y - point.y) <= $0.hitTestRadius }
            .min { hypot($0.position.x - point.x, $0.position.y - point.y) < hypot($1.position.x - point.x, $1.position.y - point.y) }
    }

    /// Fires the blaster at a targeted cluster: the cluster freezes in
    /// place (stops falling) the instant it's targeted — so the water shot
    /// visibly travels to and hits *this specific cluster*, not empty air
    /// where it used to be — then the existing splash/score/sound land on
    /// arrival, a beat later.
    private func fireAtParticle(_ node: ParticleTargetNode) {
        activeParticles.removeAll { $0 === node }
        node.removeAllActions()
        let targetPosition = node.position
        let density = node.density
        let color = ParticleTargetNode.fillColor(for: density)

        blasterNode.fire()
        WaterShotNode.spawn(in: self, from: blasterNode.position, to: targetPosition, reduceMotion: reduceMotion) { [weak self, weak node] in
            guard let self else { return }
            node?.removeFromParent()
            // The round can finish while a shot is still mid-flight (tapped
            // a target in the round's last ~100ms) — `registerHit` already
            // no-ops and returns 0 once `isRoundComplete`, but without this
            // guard the splash/score-popup/sound would still fire a hollow
            // "+0" right as the view hands off to the result screen.
            guard !self.hasFinished else { return }
            SplashEffectNode.spawn(in: self, at: targetPosition, color: color, reduceMotion: self.reduceMotion)
            let awarded = self.state.registerHit(density: density)
            ScorePopupNode.spawn(in: self, at: targetPosition, points: awarded, isBonus: density == .heavy, reduceMotion: self.reduceMotion)
            switch density {
            case .light: self.soundPlayer?.play(.lightHit)
            case .medium: self.soundPlayer?.play(.mediumHit)
            case .heavy: self.soundPlayer?.play(.heavyHit)
            }
        }
    }

    /// Correct interaction: the player dragged through the boost.
    private func activateBoost(_ node: EnvironmentalBoostNode) {
        activeBoosts.removeAll { $0 === node }
        let kind = node.kind
        node.removeAllActions()
        node.removeFromParent()

        switch kind {
        case .wind:
            sweepParticlesAway()
        case .rain:
            washAwayParticles(maxCount: 3)
        }
        EnvironmentalSweepEffect.spawn(in: self, kind: kind, reduceMotion: reduceMotion)
        let contributionPercent = kind == .wind ? scenario.windContributionPercent : scenario.precipitationContributionPercent
        state.registerBoostActivated(kind: kind, elapsed: elapsed, contributionPercent: contributionPercent)
        soundPlayer?.play(.boostActivate)
    }

    /// Mistake: the player tapped the boost like a harmful target.
    private func strikeBoostIncorrectly(_ node: EnvironmentalBoostNode) {
        activeBoosts.removeAll { $0 === node }
        let kind = node.kind
        node.removeAllActions()
        // A brief shake + fade rather than a green splash — visually
        // distinct negative feedback, paired with the callout text (never
        // color alone, work order §16).
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 6, y: 0, duration: 0.04),
            SKAction.moveBy(x: -12, y: 0, duration: 0.06),
            SKAction.moveBy(x: 12, y: 0, duration: 0.06),
            SKAction.moveBy(x: -6, y: 0, duration: 0.04),
        ])
        let fade = SKAction.fadeOut(withDuration: reduceMotion ? 0.15 : 0.3)
        let group = reduceMotion ? SKAction.group([fade]) : SKAction.group([shake, fade])
        node.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        state.registerIncorrectHit(kind: kind, elapsed: elapsed)
        soundPlayer?.play(.incorrectHit)
    }

    /// Wind boost effect: push every currently on-screen particle cluster
    /// off to one side (work order §9 B: "briefly pushes particle nodes
    /// away, reduces current on-screen particle load").
    private func sweepParticlesAway() {
        let swept = activeParticles
        activeParticles.removeAll()
        for node in swept {
            node.removeAllActions()
            let direction: CGFloat = Bool.random() ? 1 : -1
            let move = SKAction.moveBy(x: direction * size.width, y: 40, duration: reduceMotion ? 0.25 : 0.5)
            let fade = SKAction.fadeOut(withDuration: reduceMotion ? 0.25 : 0.5)
            node.run(SKAction.sequence([SKAction.group([move, fade]), SKAction.removeFromParent()]))
        }
        state.registerEnvironmentalSweep(particleCount: swept.count)
    }

    /// Rain boost effect: wash away a handful of active clusters (work
    /// order §9 C: "removes some active PM2.5 clusters, creates clean
    /// visual sweep").
    private func washAwayParticles(maxCount: Int) {
        let targets = Array(activeParticles.shuffled().prefix(maxCount))
        for node in targets {
            activeParticles.removeAll { $0 === node }
            node.removeAllActions()
            let fall = SKAction.moveBy(x: 0, y: -80, duration: reduceMotion ? 0.25 : 0.5)
            let fade = SKAction.fadeOut(withDuration: reduceMotion ? 0.25 : 0.5)
            node.run(SKAction.sequence([SKAction.group([fall, fade]), SKAction.removeFromParent()]))
        }
        state.registerEnvironmentalSweep(particleCount: targets.count)
    }

    // MARK: Pause

    /// Called by the SwiftUI pause control — separate from SpriteKit's own
    /// `isPaused` semantics only in name; kept as one call site so the
    /// SwiftUI layer never has to know it's really just `SKScene.isPaused`.
    func setExternallyPaused(_ paused: Bool) {
        isPaused = paused
        state.setPaused(paused)
        lastUpdateTime = 0
    }

    /// Keeps this scene's Reduce Motion behavior in sync with the live
    /// system setting for the rest of the round (see the property's doc
    /// comment) — only affects *future* effects (shots, splashes, sweeps),
    /// never anything already mid-animation.
    func setReduceMotion(_ reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }
}
