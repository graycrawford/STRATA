import simd
import Foundation

/// A sphere pushed through the cloth (a hand joint). `previousCenter` lets the
/// solver apply friction relative to how the sphere moved this step.
struct SphereCollider {
    var center: SIMD3<Float>
    var previousCenter: SIMD3<Float>
    var radius: Float
}

/// Per-frame measurements of how disturbed a sheet is. These drive the audio.
struct ClothMetrics {
    /// Half-size of the sheet's bounding box measured in the sheet's own rest
    /// frame (u across, v down, n along the normal). `extents.z` is the Unity
    /// `bounds.extents` value the original scripts fed into `tanh`.
    var extents: SIMD3<Float> = .zero

    /// Mean distance of particles from their rest positions, metres.
    var meanDisplacement: Float = 0

    /// Largest particle displacement, metres.
    var maxDisplacement: Float = 0

    /// Displacement-weighted centre of the disturbance, in simulation space.
    /// Falls back to the sheet centre when nothing is moving.
    var agitationCentroid: SIMD3<Float> = .zero

    /// Mean particle speed, metres per second.
    var meanSpeed: Float = 0

    /// The value the original Unity scripts used: bounding-box half extent
    /// along the sheet normal.
    var normalExtent: Float { extents.z }
}

/// Position-based (Verlet) cloth on a regular grid.
///
/// Everything is plain Swift over contiguous arrays so it can be moved to a
/// Metal compute kernel later without changing the interface. The simulation
/// runs in the coordinate space of the scene root, not world space; callers
/// convert hand positions into that space before passing colliders in.
final class ClothSimulation {
    let columns: Int
    let rows: Int
    var parameters: ClothParameters

    /// Rest-frame axes. `origin` is the sheet centre.
    let origin: SIMD3<Float>
    let axisU: SIMD3<Float>
    let axisV: SIMD3<Float>
    let normal: SIMD3<Float>
    let width: Float
    let height: Float

    private(set) var positions: [SIMD3<Float>]
    private var previous: [SIMD3<Float>]
    private(set) var rest: [SIMD3<Float>]
    private(set) var normals: [SIMD3<Float>]
    private(set) var uvs: [SIMD2<Float>]
    private var invMass: [Float]
    private(set) var triangleIndices: [UInt32]
    private(set) var metrics = ClothMetrics()

    private struct Constraint {
        var a: Int32
        var b: Int32
        var restLength: Float
        var isBend: Bool
    }
    private var constraints: [Constraint] = []
    private var accumulator: Float = 0

    var particleCount: Int { positions.count }

    /// Axis-aligned bounds of the rest sheet, inflated so it can be used for
    /// cheap broad-phase rejection of hand spheres and as the render bounds.
    let broadPhaseMin: SIMD3<Float>
    let broadPhaseMax: SIMD3<Float>

    /// - Parameters:
    ///   - center: sheet centre in simulation space.
    ///   - right: direction across the sheet (unit length not required).
    ///   - down: direction down the sheet.
    ///   - width/height: sheet size in metres.
    ///   - resolution: particles per side.
    init(center: SIMD3<Float>,
         right: SIMD3<Float>,
         down: SIMD3<Float>,
         width: Float,
         height: Float,
         resolution: Int,
         parameters: ClothParameters) {
        self.columns = max(2, resolution)
        self.rows = max(2, resolution)
        self.parameters = parameters
        self.origin = center
        self.axisU = simd_normalize(right)
        self.axisV = simd_normalize(down - simd_dot(down, axisU) * axisU)
        self.normal = simd_normalize(simd_cross(axisU, axisV))
        self.width = width
        self.height = height

        let count = columns * rows
        var rest = [SIMD3<Float>](repeating: .zero, count: count)
        var uvs = [SIMD2<Float>](repeating: .zero, count: count)
        for r in 0..<rows {
            for c in 0..<columns {
                let fu = Float(c) / Float(columns - 1)
                let fv = Float(r) / Float(rows - 1)
                let p = center + axisU * ((fu - 0.5) * width) + axisV * ((fv - 0.5) * height)
                rest[r * columns + c] = p
                uvs[r * columns + c] = SIMD2(fu, fv)
            }
        }
        self.rest = rest
        self.positions = rest
        self.previous = rest
        self.uvs = uvs
        self.normals = [SIMD3<Float>](repeating: normal, count: count)
        self.invMass = [Float](repeating: 1, count: count)

        var indices: [UInt32] = []
        indices.reserveCapacity((columns - 1) * (rows - 1) * 6)
        for r in 0..<(rows - 1) {
            for c in 0..<(columns - 1) {
                let i0 = UInt32(r * columns + c)
                let i1 = i0 + 1
                let i2 = i0 + UInt32(columns)
                let i3 = i2 + 1
                indices += [i0, i2, i1, i1, i2, i3]
            }
        }
        self.triangleIndices = indices

        let inflate = SIMD3<Float>(repeating: max(width, height) * 0.75)
        var mn = rest[0], mx = rest[0]
        for p in rest { mn = simd_min(mn, p); mx = simd_max(mx, p) }
        self.broadPhaseMin = mn - inflate
        self.broadPhaseMax = mx + inflate

        buildConstraints()
        applyPinning()
        metrics.agitationCentroid = center
    }

    private func buildConstraints() {
        func add(_ a: Int, _ b: Int, bend: Bool) {
            constraints.append(Constraint(a: Int32(a), b: Int32(b),
                                          restLength: simd_distance(rest[a], rest[b]),
                                          isBend: bend))
        }
        for r in 0..<rows {
            for c in 0..<columns {
                let i = r * columns + c
                if c + 1 < columns { add(i, i + 1, bend: false) }
                if r + 1 < rows { add(i, i + columns, bend: false) }
                if c + 1 < columns && r + 1 < rows {
                    add(i, i + columns + 1, bend: false)
                    add(i + 1, i + columns, bend: false)
                }
                if c + 2 < columns { add(i, i + 2, bend: true) }
                if r + 2 < rows { add(i, i + 2 * columns, bend: true) }
            }
        }
    }

    private func applyPinning() {
        func pin(_ i: Int) { invMass[i] = 0 }
        switch parameters.pinning {
        case .none:
            break
        case .topEdge:
            for c in 0..<columns { pin(c) }
        case .corners:
            pin(0); pin(columns - 1); pin((rows - 1) * columns); pin(rows * columns - 1)
        case .leftEdge:
            for r in 0..<rows { pin(r * columns) }
        }
    }

    /// Snap everything back to the rest shape (used on scene reset).
    func reset() {
        positions = rest
        previous = rest
        accumulator = 0
        recomputeNormals()
        recomputeMetrics(dt: 1)
    }

    /// Advance by `deltaTime` seconds using fixed substeps.
    func step(deltaTime: Float, colliders: [SphereCollider]) {
        let dt = 1 / parameters.solverFrequency
        accumulator += min(deltaTime, dt * Float(parameters.maxSubstepsPerFrame))
        let relevant = colliders.filter { overlapsBroadPhase($0) }
        var substeps = 0
        while accumulator >= dt && substeps < parameters.maxSubstepsPerFrame {
            substep(dt: dt, colliders: relevant)
            accumulator -= dt
            substeps += 1
        }
        if substeps > 0 {
            recomputeNormals()
            recomputeMetrics(dt: dt * Float(substeps))
        }
    }

    private func overlapsBroadPhase(_ s: SphereCollider) -> Bool {
        let r = s.radius + parameters.thickness
        let c = s.center
        return c.x + r >= broadPhaseMin.x && c.x - r <= broadPhaseMax.x &&
               c.y + r >= broadPhaseMin.y && c.y - r <= broadPhaseMax.y &&
               c.z + r >= broadPhaseMin.z && c.z - r <= broadPhaseMax.z
    }

    private func substep(dt: Float, colliders: [SphereCollider]) {
        let p = parameters
        let retention = powf(max(0, 1 - p.damping), dt * 60)
        let dt2 = dt * dt
        let gravity = p.gravity
        let restSpring = p.restSpring
        let count = positions.count

        positions.withUnsafeMutableBufferPointer { pos in
            previous.withUnsafeMutableBufferPointer { prev in
                rest.withUnsafeBufferPointer { restPos in
                    invMass.withUnsafeBufferPointer { w in
                        for i in 0..<count {
                            guard w[i] > 0 else { continue }
                            let current = pos[i]
                            let velocity = (current - prev[i]) * retention
                            let accel = gravity + (restPos[i] - current) * restSpring
                            prev[i] = current
                            pos[i] = current + velocity + accel * dt2
                        }
                    }
                }
            }
        }

        let iterations = max(1, p.iterations)
        let kStretch = 1 - powf(1 - min(p.stretchStiffness, 0.999), 1 / Float(iterations))
        let kBend = 1 - powf(1 - min(p.bendStiffness, 0.999), 1 / Float(iterations))

        positions.withUnsafeMutableBufferPointer { pos in
            invMass.withUnsafeBufferPointer { w in
                constraints.withUnsafeBufferPointer { cons in
                    for _ in 0..<iterations {
                        for c in cons {
                            let a = Int(c.a), b = Int(c.b)
                            let wa = w[a], wb = w[b]
                            let wsum = wa + wb
                            guard wsum > 0 else { continue }
                            let delta = pos[b] - pos[a]
                            let len = simd_length(delta)
                            guard len > 1e-6 else { continue }
                            let k = c.isBend ? kBend : kStretch
                            let correction = delta * ((len - c.restLength) / len * k / wsum)
                            pos[a] += correction * wa
                            pos[b] -= correction * wb
                        }
                    }
                }
            }
        }

        guard !colliders.isEmpty else { return }
        let thickness = p.thickness
        let friction = p.friction
        positions.withUnsafeMutableBufferPointer { pos in
            previous.withUnsafeMutableBufferPointer { prev in
                invMass.withUnsafeBufferPointer { w in
                    for s in colliders {
                        let r = s.radius + thickness
                        let r2 = r * r
                        let sphereMotion = s.center - s.previousCenter
                        for i in 0..<count {
                            guard w[i] > 0 else { continue }
                            let d = pos[i] - s.center
                            let dist2 = simd_length_squared(d)
                            guard dist2 < r2 else { continue }
                            let dist = sqrtf(max(dist2, 1e-9))
                            let n = d / dist
                            pos[i] = s.center + n * r
                            // Friction: blend the particle's previous position toward
                            // "moving with the sphere" so tangential slip is reduced.
                            let stuck = pos[i] - sphereMotion
                            prev[i] = prev[i] + (stuck - prev[i]) * friction
                        }
                    }
                }
            }
        }
    }

    private func recomputeNormals() {
        let count = positions.count
        var acc = [SIMD3<Float>](repeating: .zero, count: count)
        acc.withUnsafeMutableBufferPointer { out in
            positions.withUnsafeBufferPointer { pos in
                triangleIndices.withUnsafeBufferPointer { idx in
                    var i = 0
                    while i + 2 < idx.count {
                        let a = Int(idx[i]), b = Int(idx[i + 1]), c = Int(idx[i + 2])
                        let n = simd_cross(pos[b] - pos[a], pos[c] - pos[a])
                        out[a] += n; out[b] += n; out[c] += n
                        i += 3
                    }
                }
            }
            for i in 0..<count {
                let len = simd_length(out[i])
                out[i] = len > 1e-9 ? out[i] / len : normal
            }
        }
        normals = acc
    }

    private func recomputeMetrics(dt: Float) {
        var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var sumDisp: Float = 0
        var maxDisp: Float = 0
        var weighted = SIMD3<Float>.zero
        var sumSpeed: Float = 0
        let count = positions.count
        positions.withUnsafeBufferPointer { pos in
            rest.withUnsafeBufferPointer { restPos in
                previous.withUnsafeBufferPointer { prev in
                    for i in 0..<count {
                        let p = pos[i]
                        let d = p - origin
                        let local = SIMD3(simd_dot(d, axisU), simd_dot(d, axisV), simd_dot(d, normal))
                        mn = simd_min(mn, local)
                        mx = simd_max(mx, local)
                        let disp = simd_distance(p, restPos[i])
                        sumDisp += disp
                        maxDisp = max(maxDisp, disp)
                        weighted += p * disp
                        sumSpeed += simd_distance(p, prev[i])
                    }
                }
            }
        }
        metrics.extents = (mx - mn) * 0.5
        metrics.meanDisplacement = sumDisp / Float(count)
        metrics.maxDisplacement = maxDisp
        metrics.agitationCentroid = sumDisp > 1e-6 ? weighted / sumDisp : origin
        metrics.meanSpeed = dt > 0 ? sumSpeed / Float(count) / dt : 0
    }

    /// True when any part of `point` (with radius) is inside the inflated rest
    /// volume of the sheet — the equivalent of Unity's cloth trigger volume.
    func containsInTriggerVolume(_ point: SIMD3<Float>, radius: Float, depth: Float = 0.06) -> Bool {
        let d = point - origin
        let u = simd_dot(d, axisU), v = simd_dot(d, axisV), n = simd_dot(d, normal)
        return abs(u) <= width * 0.5 + radius &&
               abs(v) <= height * 0.5 + radius &&
               abs(n) <= depth + radius
    }
}
