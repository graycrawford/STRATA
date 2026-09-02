import RealityKit
import simd

/// The `9.5-intro` scene: a glowing cube floating in front of you and a sheet
/// behind it that hums when touched. Poking the cube starts STRATA.
@MainActor
final class IntroScene {
    let root = Entity()
    private(set) var instruments: [ClothInstrument] = []
    private let cube: ModelEntity
    private let handTrigger = HandStemTrigger()
    private var pokeDwell: Float = 0
    private var pulseCooldown: Float = 0

    /// Set for one frame when the cube has been poked.
    private(set) var pokeTriggered = false

    init() throws {
        root.name = "intro"
        let mesh = MeshResource.generateBox(size: StrataLayout.pokeCubeSize, cornerRadius: 0.004)
        cube = ModelEntity(mesh: mesh, materials: [StrataMaterials.emissiveWhite()])
        cube.name = "poke-cube"
        cube.position = StrataLayout.pokeCubeCenter
        root.addChild(cube)

        let sheet = try ClothInstrument(
            name: "intro-sheet",
            center: StrataLayout.introSheetCenter, right: SIMD3(1, 0, 0), down: SIMD3(0, -1, 0),
            size: StrataLayout.introSheetSize, resolution: StrataLayout.introSheetResolution,
            parameters: .intro, material: StrataMaterials.fwsClearBlue(opacity: 0.28),
            target: .stemLevel(.introSheet))
        instruments.append(sheet)
        root.addChild(sheet.entity)
    }

    func loadAudio(into audio: StemEngine) {
        audio.load(.introSheet, file: "backing extra melody", rate: 1.0, bus: .cloths, echoSend: true)
        for file in HandStemTrigger.files.values {
            audio.preloadOneShot(file: file)
        }
    }

    func start(audio: StemEngine) {
        pokeTriggered = false
        pokeDwell = 0
        for instrument in instruments { instrument.reset() }
        handTrigger.reset()
        cube.scale = .one
        audio.playAllStems(from: [.introSheet])
    }

    func update(deltaTime: Float, colliders: [SphereCollider], hands: [(HandPose.Side, [SphereCollider])], audio: StemEngine) {
        pokeTriggered = false
        for instrument in instruments {
            instrument.update(deltaTime: deltaTime, colliders: colliders, audio: audio)
        }
        handTrigger.update(deltaTime: deltaTime, hands: hands, instruments: instruments, audio: audio)

        let half = StrataLayout.pokeCubeSize * 0.5
        let touching = colliders.contains { s in
            let d = simd_abs(s.center - StrataLayout.pokeCubeCenter)
            return d.x <= half + s.radius && d.y <= half + s.radius && d.z <= half + s.radius
        }
        pulseCooldown = max(0, pulseCooldown - deltaTime)
        if touching {
            pokeDwell += deltaTime
            if pulseCooldown == 0 {
                pulseCooldown = 0.6
                cube.move(to: Transform(scale: SIMD3(repeating: 1.25), rotation: cube.orientation, translation: cube.position),
                          relativeTo: root, duration: 0.12, timingFunction: .easeOut)
            }
            if pokeDwell >= 0.1 {
                pokeTriggered = true
            }
        } else {
            pokeDwell = 0
            if cube.scale.x > 1.001 {
                cube.move(to: Transform(scale: .one, rotation: cube.orientation, translation: cube.position),
                          relativeTo: root, duration: 0.25, timingFunction: .easeInOut)
            }
        }
        cube.orientation = simd_quatf(angle: deltaTime * 0.35, axis: SIMD3(0, 1, 0)) * cube.orientation
    }
}
