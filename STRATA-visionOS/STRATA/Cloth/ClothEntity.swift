import Metal
import RealityKit
import simd

/// A RealityKit entity whose mesh is rewritten every frame from a
/// `ClothSimulation`, using `LowLevelMesh` so the vertex upload is a straight
/// memcpy into a GPU-visible buffer.
@MainActor
final class ClothEntity {
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var uv: SIMD2<Float>
    }

    let simulation: ClothSimulation
    let entity: ModelEntity
    private let lowLevelMesh: LowLevelMesh

    init(simulation: ClothSimulation, material: Material, name: String) throws {
        self.simulation = simulation

        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexCapacity = simulation.particleCount
        descriptor.indexCapacity = simulation.triangleIndices.count
        descriptor.vertexAttributes = [
            LowLevelMesh.Attribute(semantic: .position, format: .float3,
                                   offset: MemoryLayout<Vertex>.offset(of: \.position)!),
            LowLevelMesh.Attribute(semantic: .normal, format: .float3,
                                   offset: MemoryLayout<Vertex>.offset(of: \.normal)!),
            LowLevelMesh.Attribute(semantic: .uv0, format: .float2,
                                   offset: MemoryLayout<Vertex>.offset(of: \.uv)!),
        ]
        descriptor.vertexLayouts = [
            LowLevelMesh.Layout(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)
        ]
        descriptor.indexType = .uint32

        let mesh = try LowLevelMesh(descriptor: descriptor)
        let indices = simulation.triangleIndices
        mesh.withUnsafeMutableIndices { raw in
            let out = raw.bindMemory(to: UInt32.self)
            for (i, v) in indices.enumerated() { out[i] = v }
        }
        let bounds = BoundingBox(min: simulation.broadPhaseMin, max: simulation.broadPhaseMax)
        mesh.parts.replaceAll([
            LowLevelMesh.Part(indexCount: indices.count, topology: .triangle, bounds: bounds)
        ])
        self.lowLevelMesh = mesh

        let resource = try MeshResource(from: mesh)
        let model = ModelEntity(mesh: resource, materials: [material])
        model.name = name
        self.entity = model
        upload()
    }

    /// Copy the current simulation state into the GPU vertex buffer.
    func upload() {
        let positions = simulation.positions
        let normals = simulation.normals
        let uvs = simulation.uvs
        lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let out = raw.bindMemory(to: Vertex.self)
            for i in 0..<positions.count {
                out[i] = Vertex(position: positions[i], normal: normals[i], uv: uvs[i])
            }
        }
    }
}
