import simd

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }

    /// Applies the full affine transform (rotation, scale, translation) to a point.
    func transformPoint(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let v = self * SIMD4(p, 1)
        return SIMD3(v.x, v.y, v.z)
    }

    /// Applies only the linear part to a direction.
    func transformDirection(_ d: SIMD3<Float>) -> SIMD3<Float> {
        let v = self * SIMD4(d, 0)
        return SIMD3(v.x, v.y, v.z)
    }

    /// Uniform scale factor, assuming the matrix has no shear.
    var uniformScale: Float {
        simd_length(SIMD3(columns.0.x, columns.0.y, columns.0.z))
    }

    static func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4(t, 1)
        return m
    }
}

extension Float {
    func clamped(_ lo: Float, _ hi: Float) -> Float {
        Swift.min(Swift.max(self, lo), hi)
    }
}

func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
}
