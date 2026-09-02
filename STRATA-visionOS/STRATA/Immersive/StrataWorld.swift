import ARKit
import RealityKit
import UIKit
import simd

/// Owns the whole immersive experience: tracking, audio, the two scenes and
/// the timeline. Ticked once per render frame by `StrataTickSystem`.
@MainActor
final class StrataWorld {
    /// The single live instance, reached from the RealityKit system.
    static var shared: StrataWorld?

    enum Phase { case intro, strata }

    let appModel: AppModel
    let tracking = TrackingSession()
    let audio = StemEngine()

    /// Scaled during the end-of-piece "GlobalShrink". Everything the hands
    /// touch lives under here, so the shrink also shrinks the instruments.
    let contentRoot = Entity()
    /// Unscaled: sky, lights, hand markers.
    let overlayRoot = Entity()

    private(set) var phase: Phase = .intro
    private var intro: IntroScene?
    private var strata: StrataScene?
    private var elapsed: Float = 0
    private var started = false
    private var handMarkers: [ModelEntity] = []
    private var lastHeadPosition: SIMD3<Float>?
    private var previousJointPositions: [HandPose.Side: [HandSkeleton.JointName: SIMD3<Float>]] = [:]
    private var headSpeed = Smoothed(0, timeConstant: 0.25)

    private static let shrinkPivot = SIMD3<Float>(0, 1.15, -0.5)

    init(appModel: AppModel) {
        self.appModel = appModel
        contentRoot.name = "content"
        overlayRoot.name = "overlay"
    }

    // MARK: - Setup

    func attach(to content: inout RealityViewContent) {
        content.add(contentRoot)
        content.add(overlayRoot)
        addSky()
        addLights()
        addHandMarkers()
    }

    func start() async {
        guard !started else { return }
        started = true
        let plinks = Self.loadTineSamples()
        do {
            let intro = try IntroScene()
            let strata = try StrataScene(tineSamples: plinks)
            self.intro = intro
            self.strata = strata
            intro.loadAudio(into: audio)
            strata.loadAudio(into: audio)
        } catch {
            print("STRATA: failed to build scenes: \(error)")
            return
        }
        audio.start()
        await tracking.start()
        enterIntro()
    }

    func shutdown() {
        audio.stopAllStems()
        tracking.stop()
        Self.shared = nil
    }

    private static func loadTineSamples() -> [AudioFileResource] {
        let names = ["plink echo 1", "plink echo 1.1", "plink echo 2", "plink echo 3", "plink echo 4",
                     "plink echo 5", "plink echo 6", "plink echo 7", "plink echo 8", "plink echo 9",
                     "plink echo 10", "plink echo 11"]
        var resources: [AudioFileResource] = []
        for name in names {
            guard let url = AudioAssets.url(named: name) else { continue }
            if let resource = try? AudioFileResource.load(contentsOf: url, inputMode: .spatial,
                                                          loadingStrategy: .preload, shouldLoop: false) {
                resources.append(resource)
            }
        }
        if resources.isEmpty { print("STRATA: no plink samples found; tines will be silent") }
        return resources
    }

    private func addSky() {
        guard let texture = Self.makeSkyTexture() else { return }
        var material = UnlitMaterial()
        material.color = .init(texture: .init(texture))
        material.faceCulling = .front
        let sky = ModelEntity(mesh: .generateSphere(radius: 40), materials: [material])
        sky.name = "sky"
        sky.position = SIMD3(0, 1.2, 0)
        overlayRoot.addChild(sky)
    }

    /// A vertical gradient: Unity's ambient grey-blue at the horizon fading to
    /// near-black overhead and a darker ground.
    private static func makeSkyTexture() -> TextureResource? {
        let width = 8, height = 256
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [
            UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1).cgColor,   // zenith
            UIColor(red: 0.212, green: 0.227, blue: 0.259, alpha: 1).cgColor, // horizon
            UIColor(red: 0.05, green: 0.045, blue: 0.045, alpha: 1).cgColor,  // ground
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1]) else { return nil }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: .zero, options: [])
        guard let image = ctx.makeImage() else { return nil }
        return try? TextureResource.generate(from: image, options: .init(semantic: .color))
    }

    private func addLights() {
        let key = Entity()
        var directional = DirectionalLightComponent()
        directional.intensity = 1200
        key.components.set(directional)
        key.look(at: SIMD3(0.4, 0, -1), from: SIMD3(-0.4, 3, 1), relativeTo: nil)
        overlayRoot.addChild(key)

        let fill = Entity()
        var point = PointLightComponent()
        point.intensity = 900
        point.attenuationRadius = 6
        point.color = UIColor(red: 0.7, green: 0.8, blue: 1, alpha: 1)
        fill.components.set(point)
        fill.position = SIMD3(0.8, 1.9, 0.3)
        overlayRoot.addChild(fill)
    }

    private func addHandMarkers() {
        let mesh = MeshResource.generateSphere(radius: 0.005)
        for _ in 0..<10 {
            let marker = ModelEntity(mesh: mesh, materials: [StrataMaterials.emissiveWhite()])
            marker.isEnabled = false
            overlayRoot.addChild(marker)
            handMarkers.append(marker)
        }
    }

    // MARK: - Phases

    private func enterIntro() {
        guard let intro else { return }
        phase = .intro
        elapsed = 0
        strata?.root.removeFromParent()
        strata?.stop(audio: audio)
        setShrink(1)
        contentRoot.addChild(intro.root)
        intro.start(audio: audio)
        appModel.phaseDescription = "Poke the cube to begin"
    }

    private func enterStrata() {
        guard let strata else { return }
        phase = .strata
        elapsed = 0
        intro?.root.removeFromParent()
        audio.stopAllStems()
        setShrink(1)
        strata.root.scale = SIMD3(repeating: 0.05)
        contentRoot.addChild(strata.root)
        strata.root.move(to: Transform(scale: .one, rotation: simd_quatf(), translation: .zero),
                         relativeTo: contentRoot, duration: 1.6, timingFunction: .easeOut)
        strata.start(audio: audio)
        appModel.phaseDescription = "STRATA"
    }

    private func setShrink(_ scale: Float) {
        contentRoot.scale = SIMD3(repeating: scale)
        contentRoot.position = Self.shrinkPivot * (1 - scale)
    }

    // MARK: - Per-frame

    func tick(deltaTime: Float) {
        guard started, let intro, let strata else { return }
        let dt = min(deltaTime, 1 / 30)
        let snapshot = tracking.snapshot()

        // Hand spheres into the (possibly shrunken) content space.
        let worldFromContent = contentRoot.transformMatrix(relativeTo: nil)
        let contentFromWorld = worldFromContent.inverse
        let inverseScale = 1 / max(worldFromContent.uniformScale, 1e-4)

        var allColliders: [SphereCollider] = []
        var perHand: [(HandPose.Side, [SphereCollider])] = []
        for hand in snapshot.hands {
            var spheres: [SphereCollider] = []
            var joints: [HandSkeleton.JointName: SIMD3<Float>] = [:]
            let previous = previousJointPositions[hand.side] ?? [:]
            for joint in hand.joints {
                let now = contentFromWorld.transformPoint(joint.position)
                let before = previous[joint.name].map { contentFromWorld.transformPoint($0) } ?? now
                spheres.append(SphereCollider(center: now, previousCenter: before,
                                              radius: joint.radius * inverseScale))
                joints[joint.name] = joint.position
            }
            previousJointPositions[hand.side] = joints
            perHand.append((hand.side, spheres))
            allColliders += spheres
        }
        if snapshot.left == nil { previousJointPositions[.left] = nil }
        if snapshot.right == nil { previousJointPositions[.right] = nil }

        updateHandMarkers(snapshot)
        updateHeadVelocity(snapshot, dt: dt)

        switch phase {
        case .intro:
            intro.update(deltaTime: dt, colliders: allColliders, hands: perHand, audio: audio)
            if intro.pokeTriggered { enterStrata() }
        case .strata:
            elapsed += dt
            strata.update(deltaTime: dt, colliders: allColliders, hands: perHand, audio: audio)
            if elapsed >= StrataLayout.shrinkStart {
                let t = ((elapsed - StrataLayout.shrinkStart) / (StrataLayout.shrinkEnd - StrataLayout.shrinkStart)).clamped(0, 1)
                let eased = t * t * (3 - 2 * t)
                setShrink(mix(1, StrataLayout.shrinkScale, eased))
            }
            if elapsed >= StrataLayout.experienceDuration { enterIntro() }
        }

        audio.advance(deltaTime: dt)
    }

    private func updateHandMarkers(_ snapshot: TrackingSnapshot) {
        let tips = snapshot.hands.flatMap(\.fingertips)
        for (i, marker) in handMarkers.enumerated() {
            if appModel.showHandMarkers, i < tips.count {
                marker.isEnabled = true
                marker.position = tips[i]
            } else {
                marker.isEnabled = false
            }
        }
    }

    /// Unity `HeadVelocitySurfacing`: faster head movement opens up the
    /// Background+Head bus.
    private func updateHeadVelocity(_ snapshot: TrackingSnapshot, dt: Float) {
        guard let head = snapshot.headTransform?.translation else { return }
        if let last = lastHeadPosition, dt > 0 {
            headSpeed.target = simd_distance(head, last) / dt
        }
        lastHeadPosition = head
        let speed = headSpeed.advance(dt)
        audio.setBackgroundLevel(decibels: AudioMapping.headVelocityDecibels(speed: speed * 2))
    }
}

/// RealityKit calls this every frame on the main thread; it forwards to the world.
struct StrataTickSystem: System {
    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        MainActor.assumeIsolated {
            StrataWorld.shared?.tick(deltaTime: dt)
        }
    }
}
