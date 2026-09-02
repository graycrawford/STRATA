import RealityKit
import simd

/// The grid of little capsules from `7 - cloth tines hands`: each one owns a
/// fixed `plink echo` sample and plays it, spatialised at its own position,
/// when a fingertip crosses it (Unity `PlayTine`).
@MainActor
final class TineField {
    private struct Tine {
        let entity: ModelEntity
        let base: SIMD3<Float>
        let top: SIMD3<Float>
        let sample: Int
        let voiced: Bool
        var touching = false
        var glow: Float = 0
    }

    let root = Entity()
    private var tines: [Tine] = []
    private let samples: [AudioFileResource]
    private let litMaterial = StrataMaterials.fwsEmissive()
    private let restMaterial: PhysicallyBasedMaterial = {
        var m = StrataMaterials.fwsEmissive()
        m.emissiveIntensity = 0.35
        return m
    }()

    /// Gain applied to every plink, dB (Unity `Tines` bus, `Sub2Volume`).
    var gainDb: Float = -4

    init(samples: [AudioFileResource]) {
        self.samples = samples
        root.name = "tines"
        buildGrid()
    }

    private func buildGrid() {
        let mesh = MeshResource.generateCylinder(height: StrataLayout.tineHeight, radius: StrataLayout.tineRadius)
        let cols = StrataLayout.tineColumns, rows = StrataLayout.tineRows
        let half = SIMD3<Float>(Float(cols - 1) * StrataLayout.tineSpacingX * 0.5, 0,
                                Float(rows - 1) * StrataLayout.tineSpacingZ * 0.5)
        var rng = SystemRandomNumberGenerator()
        for r in 0..<rows {
            for c in 0..<cols {
                let offset = SIMD3<Float>(Float(c) * StrataLayout.tineSpacingX, 0, Float(r) * StrataLayout.tineSpacingZ) - half
                let base = StrataLayout.tineFieldCenter + offset
                let entity = ModelEntity(mesh: mesh, materials: [restMaterial])
                entity.position = base + SIMD3(0, StrataLayout.tineHeight * 0.5, 0)
                entity.name = "tine-\(r)-\(c)"
                entity.spatialAudio = SpatialAudioComponent(gain: 0)
                root.addChild(entity)
                let sample = samples.isEmpty ? 0 : Int.random(in: 0..<samples.count, using: &rng)
                let voiced = Float.random(in: 0..<1, using: &rng) < StrataLayout.tineVoicedProbability
                tines.append(Tine(entity: entity, base: base,
                                  top: base + SIMD3(0, StrataLayout.tineHeight, 0),
                                  sample: sample, voiced: voiced))
            }
        }
    }

    func update(deltaTime: Float, colliders: [SphereCollider]) {
        guard !tines.isEmpty else { return }
        for i in tines.indices {
            var tine = tines[i]
            let hit = colliders.contains { sphere in
                Self.distanceToSegment(sphere.center, a: tine.base, b: tine.top) < sphere.radius + StrataLayout.tineRadius
            }
            if hit && !tine.touching {
                pluck(&tine)
            }
            tine.touching = hit
            if tine.glow > 0 {
                tine.glow = max(0, tine.glow - deltaTime * 2.5)
                var m = restMaterial
                m.emissiveIntensity = mix(0.35, 3.0, tine.glow)
                tine.entity.model?.materials = [m]
            }
            tines[i] = tine
        }
    }

    private func pluck(_ tine: inout Tine) {
        tine.glow = 1
        guard tine.voiced, !samples.isEmpty else { return }
        let controller = tine.entity.playAudio(samples[tine.sample])
        controller.gain = Double(gainDb)
    }

    func reset() {
        for i in tines.indices {
            tines[i].touching = false
            tines[i].glow = 0
            tines[i].entity.model?.materials = [restMaterial]
        }
    }

    private static func distanceToSegment(_ p: SIMD3<Float>, a: SIMD3<Float>, b: SIMD3<Float>) -> Float {
        let ab = b - a
        let t = (simd_dot(p - a, ab) / max(simd_length_squared(ab), 1e-9)).clamped(0, 1)
        return simd_distance(p, a + ab * t)
    }
}
