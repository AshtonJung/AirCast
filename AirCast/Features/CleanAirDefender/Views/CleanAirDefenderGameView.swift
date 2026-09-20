import SwiftUI
import SpriteKit
import UIKit

/// Hosts the SpriteKit round inside AirCast's chrome: pause control, exit
/// confirmation, and a haze overlay that visibly clears as the player
/// succeeds. All gameplay bookkeeping lives in `CleanAirDefenderScene` +
/// `CleanAirDefenderGameState`; this view only reacts to
/// `gameState.isRoundComplete` to hand off to the result screen.
struct CleanAirDefenderGameView: View {
    let scenario: GameScenario
    let onRoundComplete: (GameResult) -> Void
    let onExit: () -> Void

    @State private var gameState: CleanAirDefenderGameState
    @State private var scene: CleanAirDefenderScene
    @State private var isPaused = false
    /// Fires once, the first time `hazeLevel` drops below the "visibly
    /// clear" threshold — a single celebratory beat so the dirty→clean
    /// payoff has a distinct moment, not just a slow continuous fade.
    @State private var hasCelebratedClarity = false
    @State private var clarityFlashOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Same key the Entry screen's toggle writes to — read once here since
    /// the scene owns its own `GameSoundPlayer` instance for the round's
    /// lifetime rather than re-reading `@AppStorage` from SpriteKit code.
    @AppStorage(GameSoundPlayer.preferenceKey) private var soundEnabled = true

    init(scenario: GameScenario, onRoundComplete: @escaping (GameResult) -> Void, onExit: @escaping () -> Void) {
        self.scenario = scenario
        self.onRoundComplete = onRoundComplete
        self.onExit = onExit
        // Clamped so a hazardous-forecast round doesn't start the sky
        // already fully opaque (unplayable-looking) and a clean-air round
        // doesn't start with zero atmosphere to visibly clear.
        let initialHaze = max(0.2, min(scenario.severity, 0.65))
        // Names AirCast's actual mechanism — today's PM2.5 persistence vs.
        // wind/rain removal — in the model's own vocabulary, shown before a
        // single particle spawns. This is what makes the round legible as
        // "a playable version of the forecast model," not a reskinned
        // arcade game that happens to show some real numbers in the HUD.
        let introCallout: GameCallout? = scenario.currentPM25.map { current in
            GameCallout(
                title: "TODAY'S PERSISTENCE",
                message: "\(Int(current.rounded())) µg/m³ of today's PM2.5 carries into tomorrow's forecast unless wind and rain remove it. Clear clusters and protect boosts to drive persistence down.",
                tone: .info
            )
        }
        let state = CleanAirDefenderGameState(duration: scenario.duration, initialHazeLevel: initialHaze, introCallout: introCallout)
        _gameState = State(initialValue: state)
        // `@Environment(\.accessibilityReduceMotion)` isn't available at
        // init time (no view hierarchy yet), and the scene is a SpriteKit
        // object rather than a SwiftUI view, so it reads the same system
        // flag directly rather than needing it threaded in after the fact.
        // Same for the sound-enabled preference: read the raw UserDefaults
        // value here (defaulting true, matching the `@AppStorage` default
        // above) since `@AppStorage`'s projected value isn't available until
        // the view is installed in a hierarchy either.
        let soundEnabledAtLaunch = (UserDefaults.standard.object(forKey: GameSoundPlayer.preferenceKey) as? Bool) ?? true
        _scene = State(initialValue: CleanAirDefenderScene(
            scenario: scenario,
            state: state,
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            soundPlayer: soundEnabledAtLaunch ? GameSoundPlayer(enabled: true) : nil
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // The literal Home-hero skyline (buildings included, not just
            // ambient sky) — the same `SmogSkylineView` scene, same
            // buildings, same fog — so it's immediately, visually obvious
            // this round is clearing haze off *the exact city skyline shown
            // on Home*, not a generic arcade backdrop that only *explains*
            // its connection to AirCast in text. Severity tracks
            // `gameState.hazeLevel` live, so the skyline visibly sharpens as
            // the player clears clusters. `showGround: false` keeps the
            // lower two-thirds of the screen clear for falling particles.
            SmogSkylineView(
                category: scenario.category,
                severity: gameState.hazeLevel,
                reduceMotion: reduceMotion,
                showSkyline: true,
                showGround: false
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .animation(.easeOut(duration: 0.4), value: gameState.hazeLevel)

            // Ambient grime: the same drifting-motes technique used for
            // AirCast's page backgrounds elsewhere, but here reused as a
            // *continuous* visualization of "how dirty the air in this
            // scene currently is" — independent of any single falling
            // target, so the whole screen reads as genuinely hazy at the
            // start and visibly clears as `hazeLevel` drops, not just the
            // handful of PM2.5 clusters you're actively tapping. Sits
            // beneath the SpriteKit layer so the tappable targets stay the
            // clear, frontmost, unambiguous thing to touch.
            ParticleFieldOverlay(tint: scenario.category.color, severity: gameState.hazeLevel)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            // SpriteView's own background is clear (set on `scene`) so the
            // SmogSkylineView sky shows through behind the falling particle
            // clusters/boosts — the SpriteKit layer only draws gameplay,
            // never a competing solid background.
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
                // The play surface itself has no discrete VoiceOver-navigable
                // elements (targets fall and disappear in under a second);
                // the HUD and pause/exit controls below carry accessibility.
                .accessibilityHidden(true)

            // Legibility scrim: the sky beneath can be bright on a clean-air
            // round, so the white HUD text below keeps contrast regardless
            // of the current sky/fog color (work order §16: adequate
            // contrast) — a fixed dark gradient, not tied to hazeLevel.
            LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 170)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Haze layer: a translucent tint over the whole scene that fades
            // as the player clears clusters — the "dirty → clean" read
            // required by work order §7, independent of any single sprite,
            // layered on top of the 3D fog for extra read-through-touch
            // feel. Opacity range widened (was 0.35 max) so a round that
            // starts genuinely hazy *looks* oppressive at the start and the
            // drop to clear reads as a real payoff, not a subtle tint shift.
            Color(red: 0.38, green: 0.32, blue: 0.24)
                .opacity(gameState.hazeLevel * 0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.4), value: gameState.hazeLevel)

            // A single bright "it's clear now" flash — plays once, the
            // moment persistence first drops below a genuinely-clear
            // threshold (triggered from `.onChange` below), so the
            // dirty→clean transformation has one distinct, felt payoff beat
            // rather than only reading as a slow continuous fade.
            Color.white
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(clarityFlashOpacity)

            VStack {
                GameHUDView(
                    score: gameState.score,
                    combo: gameState.combo,
                    timeRemaining: gameState.timeRemaining,
                    hazeLevel: gameState.hazeLevel,
                    forecastPM25: scenario.forecastPM25,
                    onPause: pause
                )
                if let callout = gameState.activeCallout {
                    GameCalloutBannerView(callout: callout)
                        .padding(.top, ACSpacing.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: gameState.activeCallout)
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onChange(of: reduceMotion) { _, newValue in
            scene.setReduceMotion(newValue)
        }
        .onChange(of: gameState.hazeLevel) { _, newValue in
            guard !hasCelebratedClarity, newValue < 0.15 else { return }
            hasCelebratedClarity = true
            let peak = reduceMotion ? 0.22 : 0.5
            withAnimation(.easeOut(duration: 0.12)) { clarityFlashOpacity = peak }
            withAnimation(.easeOut(duration: 0.55).delay(0.12)) { clarityFlashOpacity = 0 }
        }
        .sensoryFeedback(.success, trigger: hasCelebratedClarity) { _, celebrated in celebrated }
        .onChange(of: gameState.isRoundComplete) { _, isComplete in
            if isComplete {
                onRoundComplete(gameState.makeResult())
            }
        }
        // Haptics (work order §17). Every one of these already has a visual
        // equivalent (splash, callout banner, result screen) — sound/haptics
        // are additive feedback, never load-bearing for understanding what
        // happened (§16: "haptics should have visual equivalents").
        .sensoryFeedback(.impact(weight: .light), trigger: gameState.particlesCleared)
        .sensoryFeedback(.success, trigger: gameState.helpfulFactorsProtected)
        .sensoryFeedback(.warning, trigger: gameState.incorrectHits)
        .sensoryFeedback(.success, trigger: gameState.isRoundComplete) { _, isComplete in isComplete }
        .alert("Paused", isPresented: $isPaused) {
            Button("Resume") { resume() }
            Button("Exit Round", role: .destructive) { onExit() }
        } message: {
            Text("Your progress in this round will be lost if you exit.")
        }
    }

    private func pause() {
        isPaused = true
        scene.setExternallyPaused(true)
    }

    private func resume() {
        isPaused = false
        scene.setExternallyPaused(false)
    }
}
