import RealityKit
import simd

/// Everything in the main `10-strata` scene.
@MainActor
final class StrataScene {
    let root = Entity()
    private(set) var instruments: [ClothInstrument] = []
    let tines: TineField
    private let handTrigger = HandStemTrigger()

    init(tineSamples: [AudioFileResource]) throws {
        root.name = "strata"
        tines = TineField(samples: tineSamples)
        try build()
    }

    private func build() throws {
        let toViewer = SIMD3<Float>(0, 0, 1)
        let right = SIMD3<Float>(1, 0, 0)
        let down = SIMD3<Float>(0, -1, 0)

        // The stack: sheets face the viewer, stepping away along -z.
        for (i, layer) in StrataLayout.layers.enumerated() {
            let center = StrataLayout.stackCenter - toViewer * (Float(i) * StrataLayout.stackSpacing)
            let target: ClothInstrument.Target
            if let stem = layer.stem {
                target = .stemLevel(stem)
            } else if layer.drivesStrataLowpass {
                target = .strataLowpass
            } else {
                target = .none
            }
            let instrument = try ClothInstrument(
                name: "strata-layer-\(i)",
                center: center, right: right, down: down,
                size: StrataLayout.stackSheetSize,
                resolution: StrataLayout.stackResolution,
                parameters: .strataLayer,
                material: StrataMaterials.strataLayer(index: i),
                target: target)
            instruments.append(instrument)
        }

        // "secondary melody cloth" and its lowpass twin, low and in front.
        instruments.append(try ClothInstrument(
            name: "melody",
            center: StrataLayout.melodyCenter, right: right, down: down,
            size: StrataLayout.smallSheetSize, resolution: StrataLayout.smallSheetResolution,
            parameters: .melody, material: StrataMaterials.fws(),
            target: .stemLevel(.melody)))
        instruments.append(try ClothInstrument(
            name: "lowpass",
            center: StrataLayout.lowpassCenter, right: right, down: down,
            size: StrataLayout.smallSheetSize, resolution: StrataLayout.smallSheetResolution,
            parameters: .lowpass, material: StrataMaterials.fwsClear(opacity: 0.35),
            target: .globalLowpass))

        // The big curtain on the left, facing the viewer's left hand.
        instruments.append(try ClothInstrument(
            name: "curtain",
            center: StrataLayout.curtainCenter, right: SIMD3(0, 0, -1), down: down,
            size: StrataLayout.curtainSize, resolution: StrataLayout.curtainResolution,
            parameters: .curtain, material: StrataMaterials.fwsClearBlue(opacity: 0.3),
            target: .stemLevel(.curtain)))

        // The reverb wall on the right.
        instruments.append(try ClothInstrument(
            name: "reverb-wall",
            center: StrataLayout.wallCenter, right: SIMD3(0, 0, 1), down: down,
            size: StrataLayout.wallSize, resolution: StrataLayout.wallResolution,
            parameters: .wall, material: StrataMaterials.ghost(opacity: 0.18),
            target: .masterReverb))

        for instrument in instruments {
            root.addChild(instrument.entity)
        }
        root.addChild(tines.root)
    }

    /// Wire this scene's stems into the engine. Call once.
    func loadAudio(into audio: StemEngine) {
        for layer in StrataLayout.layers {
            if let stem = layer.stem, let file = layer.fileName {
                audio.load(stem, file: file, rate: layer.rate, bus: .strata)
            }
        }
        audio.load(.melody, file: "backing extra melody", rate: 1.0, bus: .cloths, echoSend: true)
        audio.load(.curtain, file: "backing extra melody", rate: 0.5, bus: .cloths, echoSend: true)
        audio.load(.background, file: "spawn into terroir full", rate: 1.0, bus: .background)
        for file in HandStemTrigger.files.values {
            audio.preloadOneShot(file: file)
        }
    }

    var stemIDs: [StemID] {
        StrataLayout.layers.compactMap(\.stem) + [.melody, .curtain, .background]
    }

    func start(audio: StemEngine) {
        for instrument in instruments { instrument.reset() }
        tines.reset()
        handTrigger.reset()
        audio.playAllStems(from: stemIDs)
        // The background song is not displacement-driven; it just plays.
        audio.setStemLevel(.background, decibels: -6)
    }

    func stop(audio: StemEngine) {
        audio.stopAllStems()
    }

    func update(deltaTime: Float, colliders: [SphereCollider], hands: [(HandPose.Side, [SphereCollider])], audio: StemEngine) {
        for instrument in instruments {
            instrument.update(deltaTime: deltaTime, colliders: colliders, audio: audio)
        }
        tines.update(deltaTime: deltaTime, colliders: colliders)
        handTrigger.update(deltaTime: deltaTime, hands: hands, instruments: instruments, audio: audio)
    }
}
