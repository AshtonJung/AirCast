import SwiftUI
import SceneKit
import UIKit

/// A real, explorable 3D scene: a city skyline under an open sky, obscured
/// by fog whose density is driven directly by `severity` (normalized PM2.5).
///
/// This is the literal, scientifically real effect of PM2.5 pollution —
/// reduced visibility — rendered instead of merely described: on a clean-air
/// day every building stands out crisply against the sky; on a hazardous day
/// the skyline visibly dissolves into haze just a few blocks out. Drag
/// horizontally to look around the skyline from a different angle.
///
/// Respects Reduce Motion by freezing cloud drift and the sun's slow glow
/// pulse, while keeping the (informative, not decorative) fog and skyline
/// fully in place.
struct SmogSkylineView: UIViewRepresentable {
    let category: AQICategory
    /// 0...1, typically `min(pm25 / 150, 1)`.
    let severity: Double
    var reduceMotion: Bool = false
    /// Set false for a full-screen *ambient* sky (ScrollView content sits on
    /// top) — just sky, sun, clouds, and haze, no city/ground, so it doesn't
    /// visually compete with the skyline shown in the Home hero card.
    var showSkyline: Bool = true
    var showGround: Bool = true

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = !reduceMotion

        let scene = SCNScene()
        view.scene = scene
        Self.configureFog(scene: scene, category: category, severity: severity)

        Self.addSky(to: scene, category: category, severity: severity)
        Self.addSun(to: scene, category: category, reduceMotion: reduceMotion)
        if showGround {
            Self.addGround(to: scene, category: category)
        }
        if showSkyline {
            Self.addSkyline(to: scene, category: category, reduceMotion: reduceMotion)
        }
        let clouds = Self.addClouds(to: scene)
        if !reduceMotion {
            Self.animateClouds(clouds)
        }
        Self.addHazeParticles(to: scene, category: category, severity: severity, reduceMotion: reduceMotion)

        let cameraRig = SCNNode()
        cameraRig.name = "cameraRig"
        let camera = SCNCamera()
        camera.fieldOfView = 52
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.1, 8.5)
        // Tilted slightly upward (target well above eye height) so the
        // horizon sits low in frame — more open sky and skyline, less flat
        // foreground ground plane. The ambient (no-skyline) variant looks
        // straight into open sky, since there's no city to frame.
        cameraNode.look(at: SCNVector3(0, showSkyline ? 2.6 : 4.5, 0))
        cameraRig.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraRig)
        context.coordinator.cameraRig = cameraRig

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        context.coordinator.reduceMotion = reduceMotion

        if !reduceMotion {
            let drift = SCNAction.repeatForever(.sequence([
                .rotateBy(x: 0, y: 0.22, z: 0, duration: 14),
                .rotateBy(x: 0, y: -0.22, z: 0, duration: 14),
            ]))
            cameraRig.runAction(drift, forKey: "autoDrift")
        }

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let scene = view.scene else { return }
        Self.configureFog(scene: scene, category: category, severity: severity)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var cameraRig: SCNNode?
        var reduceMotion = false
        private var dragStartRotation: Float = 0

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let rig = cameraRig else { return }
            switch gesture.state {
            case .began:
                rig.removeAction(forKey: "autoDrift")
                dragStartRotation = rig.eulerAngles.y
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                let proposed = dragStartRotation + Float(translation.x / 140)
                rig.eulerAngles.y = max(-0.9, min(0.9, proposed))
            default:
                break
            }
        }
    }

    // MARK: Scene construction

    private static func configureFog(scene: SCNScene, category: AQICategory, severity: Double) {
        let clamped = max(0, min(1, severity))
        // Blends toward the same warm horizon gold `addSky` uses, not flat
        // gray, so the fogged-out distance still reads as part of one
        // multi-color sky rather than a desaturated wash.
        let warmHaze = UIColor(red: 0.97, green: 0.85, blue: 0.68, alpha: 1)
        let haze = UIColor(category.color).blended(with: warmHaze, fraction: 0.5 + clamped * 0.2)
        scene.fogColor = haze
        scene.fogStartDistance = 3.0
        // Worse air pulls the fog in closer — the skyline visibly dissolves sooner.
        scene.fogEndDistance = 22.0 - clamped * 15.0
        scene.fogDensityExponent = 1.6
    }

    /// Sets the scene's true backdrop to a three-stop sky gradient — a cool
    /// blue-indigo zenith, the AQI category color through the middle, and a
    /// warm gold horizon. A real sky is never one flat hue, and neither is
    /// this: the category color still reads clearly (it dominates the
    /// middle band everyone looks at), but it now sits inside an actual
    /// color *combination* instead of being the only hue on screen.
    private static func addSky(to scene: SCNScene, category: AQICategory, severity: Double) {
        let zenithBase = UIColor(red: 0.16, green: 0.32, blue: 0.58, alpha: 1)
        let horizonBase = UIColor(red: 0.99, green: 0.78, blue: 0.52, alpha: 1)

        // Worse air doesn't wash the color out — real smog skies stay
        // vivid, just shifted warmer/murkier (think hazy orange sunsets),
        // so severity blends the palette toward the category color rather
        // than toward gray.
        let clamped = max(0, min(1, severity))
        let zenith = zenithBase.blended(with: UIColor(category.color), fraction: 0.2 + clamped * 0.35)
        let mid = UIColor(category.color)
        let horizon = horizonBase.blended(with: UIColor(category.color), fraction: 0.35 + clamped * 0.35)

        scene.background.contents = skyGradientImage(stops: [zenith, mid, horizon])
    }

    private static func skyGradientImage(stops: [UIColor]) -> UIImage {
        let size = CGSize(width: 8, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = stops.map { $0.cgColor } as CFArray
            let locations: [CGFloat] = stops.count == 3 ? [0, 0.55, 1] : (0..<stops.count).map { CGFloat($0) / CGFloat(max(stops.count - 1, 1)) }
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
        }
    }

    private static func addSun(to scene: SCNScene, category: AQICategory, reduceMotion: Bool) {
        let sunGeometry = SCNSphere(radius: 0.55)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.clear
        material.emission.contents = UIColor(white: 1.0, alpha: 1).blended(with: UIColor(category.color), fraction: 0.25)
        sunGeometry.materials = [material]
        let sunNode = SCNNode(geometry: sunGeometry)
        sunNode.position = SCNVector3(4.2, 8.5, -16)
        scene.rootNode.addChildNode(sunNode)

        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = 1600
        glow.color = UIColor.white
        let glowNode = SCNNode()
        glowNode.light = glow
        glowNode.position = sunNode.position
        scene.rootNode.addChildNode(glowNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 520
        ambient.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        if !reduceMotion {
            let pulse = SCNAction.repeatForever(.sequence([
                .fadeOpacity(to: 0.75, duration: 2.4),
                .fadeOpacity(to: 1.0, duration: 2.4),
            ]))
            sunNode.runAction(pulse)
        }
    }

    private static func addGround(to scene: SCNScene, category: AQICategory) {
        let plane = SCNPlane(width: 40, height: 24)
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        // Medium-light neutral (not near-black) so it blends into the fog
        // toward the horizon instead of reading as a harsh dark slab.
        material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
        material.roughness.contents = 0.95
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(0, -0.01, -4)
        scene.rootNode.addChildNode(node)
    }

    /// A simple procedural skyline: varied-height boxes at varying depths, so
    /// nearer buildings stay crisp while farther ones are the first to
    /// vanish into the fog — this is what makes the effect read as "worse
    /// air, shorter real visibility" rather than a uniform color wash.
    private static func addSkyline(to scene: SCNScene, category: AQICategory, reduceMotion: Bool) {
        let silhouette = UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 1)

        // (xOffset, depth, height, width)
        let layout: [(Float, Float, Float, Float)] = [
            (-3.2, 4.5, 2.4, 0.9), (-2.0, 5.5, 3.4, 1.1), (-0.9, 6.5, 2.0, 0.8),
            (0.4, 7.5, 4.2, 1.3), (1.6, 6.0, 2.8, 1.0), (2.8, 8.5, 3.6, 1.2),
            (-4.4, 9.5, 2.2, 1.0), (3.9, 10.5, 3.0, 1.1), (-1.4, 12.0, 3.8, 1.4),
            (1.0, 13.5, 2.6, 1.2), (4.8, 12.5, 3.2, 1.3), (-3.6, 14.5, 4.4, 1.5),
        ]

        for (index, entry) in layout.enumerated() {
            let (x, depth, height, width) = entry
            let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(width), chamferRadius: 0.02)

            // A distinct material instance per building (not a shared one) —
            // required so each building's window-light glow can flicker on
            // its own rhythm instead of every building pulsing in lockstep.
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = silhouette
            material.roughness.contents = 0.7
            material.metalness.contents = 0.1
            // A faint category-colored rim glow keeps buildings from reading
            // as flat black cutouts and ties them visually to the AQI color.
            material.emission.contents = UIColor(category.color).withAlphaComponent(0.12)
            box.materials = [material]

            let node = SCNNode(geometry: box)
            node.position = SCNVector3(x, height / 2, -depth)
            scene.rootNode.addChildNode(node)

            guard !reduceMotion else { continue }

            // City-at-dusk window-light flicker: each building dims and
            // brightens on its own staggered, slightly different rhythm —
            // this is what turns a static silhouette into a "living" skyline.
            let stagger = Double(index) * 0.35
            let period = 1.6 + Double(index % 4) * 0.5
            let flicker = SCNAction.sequence([
                .wait(duration: stagger),
                .repeatForever(.sequence([
                    .fadeOpacity(to: 0.72, duration: period),
                    .fadeOpacity(to: 1.0, duration: period),
                ])),
            ])
            node.runAction(flicker, forKey: "windowFlicker")

            // A very slight independent scale breathing adds depth-of-life
            // without ever looking like the skyline is literally shaking.
            let breathe = SCNAction.sequence([
                .wait(duration: stagger * 0.6),
                .repeatForever(.sequence([
                    .scale(to: 1.015, duration: period * 1.3),
                    .scale(to: 1.0, duration: period * 1.3),
                ])),
            ])
            node.runAction(breathe, forKey: "breathe")
        }
    }

    private static func addClouds(to scene: SCNScene) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let positions: [(Float, Float, Float, Float)] = [ // x, y, z, scale
            (-5, 7.5, -14, 1.4), (2, 8.2, -17, 1.9), (6, 6.8, -12, 1.1), (-2.5, 9.0, -19, 1.6),
        ]
        for (x, y, z, scale) in positions {
            let sphere = SCNSphere(radius: 1.0)
            sphere.segmentCount = 16
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor(white: 1.0, alpha: 0.7)
            material.blendMode = .alpha
            material.writesToDepthBuffer = false
            sphere.materials = [material]
            let node = SCNNode(geometry: sphere)
            node.scale = SCNVector3(scale * 1.8, scale * 0.55, scale * 0.8)
            node.position = SCNVector3(x, y, z)
            node.opacity = 0.55
            scene.rootNode.addChildNode(node)
            nodes.append(node)
        }
        return nodes
    }

    private static func animateClouds(_ nodes: [SCNNode]) {
        for (index, node) in nodes.enumerated() {
            let distance: Float = 3.5
            let duration = 26.0 + Double(index) * 6.0
            let drift = SCNAction.repeatForever(.sequence([
                .moveBy(x: CGFloat(distance), y: 0, z: 0, duration: duration),
                .moveBy(x: CGFloat(-distance), y: 0, z: 0, duration: duration),
            ]))
            node.runAction(drift)
        }
    }

    private static func addHazeParticles(to scene: SCNScene, category: AQICategory, severity: Double, reduceMotion: Bool) {
        let particles = SCNParticleSystem()
        let clamped = max(0, min(1, severity))
        particles.birthRate = reduceMotion ? 4 : CGFloat(8 + clamped * 60)
        particles.particleLifeSpan = 6
        particles.particleLifeSpanVariation = 2
        particles.particleSize = 0.18
        particles.particleSizeVariation = 0.08
        particles.particleColor = UIColor(category.color).withAlphaComponent(0.25)
        particles.emitterShape = SCNBox(width: 10, height: 4, length: 8, chamferRadius: 0)
        particles.birthLocation = .volume
        particles.spreadingAngle = 180
        particles.particleVelocity = 0.05
        particles.particleVelocityVariation = 0.03
        particles.isAffectedByGravity = false
        particles.blendMode = .alpha
        particles.loops = true

        let node = SCNNode()
        node.position = SCNVector3(0, 2, -8)
        node.addParticleSystem(particles)
        scene.rootNode.addChildNode(node)
    }
}

private extension UIColor {
    /// Linear-blends two colors in RGB space (fraction 0 = self, 1 = other).
    func blended(with other: UIColor, fraction: CGFloat) -> UIColor {
        let f = max(0, min(1, fraction))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * f,
            green: g1 + (g2 - g1) * f,
            blue: b1 + (b2 - b1) * f,
            alpha: a1 + (a2 - a1) * f
        )
    }
}

#Preview("SmogSkylineView — clear") {
    SmogSkylineView(category: .good, severity: 0.05)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
}

#Preview("SmogSkylineView — hazardous") {
    SmogSkylineView(category: .hazardous, severity: 0.95)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
}
