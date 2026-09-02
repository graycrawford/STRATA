import RealityKit
import simd

/// A cloth sheet wired to one audio parameter — the native equivalent of a
/// Unity cloth object carrying one of the `*Displacement*` scripts.
@MainActor
final class ClothInstrument {
    enum Target {
        case stemLevel(StemID)
        case globalLowpass
        case strataLowpass
        case masterReverb
        case none
    }

    let name: String
    let cloth: ClothEntity
    let target: Target
    var inputScaling: Float = 15

    /// Whether hands entering this sheet count as a "Cloth" trigger for the
    /// hand-held `terroir` stems (Unity `PlayHandSound2`).
    var isHandTrigger = true

    var entity: ModelEntity { cloth.entity }
    var metrics: ClothMetrics { cloth.simulation.metrics }

    init(name: String, cloth: ClothEntity, target: Target) {
        self.name = name
        self.cloth = cloth
        self.target = target
    }

    convenience init(name: String,
                     center: SIMD3<Float>,
                     right: SIMD3<Float>,
                     down: SIMD3<Float>,
                     size: Float,
                     resolution: Int,
                     parameters: ClothParameters,
                     material: Material,
                     target: Target) throws {
        let sim = ClothSimulation(center: center, right: right, down: down,
                                  width: size, height: size,
                                  resolution: resolution, parameters: parameters)
        let cloth = try ClothEntity(simulation: sim, material: material, name: name)
        self.init(name: name, cloth: cloth, target: target)
    }

    func update(deltaTime: Float, colliders: [SphereCollider], audio: StemEngine) {
        cloth.simulation.step(deltaTime: deltaTime, colliders: colliders)
        cloth.upload()
        let extent = cloth.simulation.metrics.normalExtent
        switch target {
        case .stemLevel(let id):
            audio.setStemLevel(id, decibels: AudioMapping.volumeDecibels(extent: extent, inputScaling: inputScaling))
        case .globalLowpass:
            audio.setGlobalLowpass(hertz: AudioMapping.lowpassHertz(extent: extent, inputScaling: inputScaling))
        case .strataLowpass:
            audio.setStrataLowpass(hertz: AudioMapping.lowpassHertz(extent: extent, inputScaling: inputScaling))
        case .masterReverb:
            audio.setMasterReverb(wet: AudioMapping.reverbWet(extent: extent, inputScaling: inputScaling))
        case .none:
            break
        }
    }

    func reset() {
        cloth.simulation.reset()
        cloth.upload()
    }

    func containsAny(_ colliders: [SphereCollider]) -> Bool {
        colliders.contains { cloth.simulation.containsInTriggerVolume($0.center, radius: $0.radius) }
    }
}
