import RealityKit
import UIKit

/// Approximations of the Unity Standard materials in `Assets/Materials`.
/// Names match the original `.mat` files.
enum StrataMaterials {
    /// "FWS": dark red, slightly metallic, red emissive.
    static func fws() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.29, green: 0.0, blue: 0.0, alpha: 1))
        m.metallic = .init(floatLiteral: 0.28)
        m.roughness = .init(floatLiteral: 0.85)
        m.emissiveColor = .init(color: UIColor(red: 1, green: 0.05, blue: 0.02, alpha: 1))
        m.emissiveIntensity = 0.9
        m.faceCulling = .none
        return m
    }

    /// "FWS clear blue": nearly transparent with a cool blue emissive glow.
    static func fwsClearBlue(opacity: Float = 0.18) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 1))
        m.metallic = .init(floatLiteral: 0.3)
        m.roughness = .init(floatLiteral: 0.7)
        m.emissiveColor = .init(color: UIColor(red: 0.13, green: 0.29, blue: 0.66, alpha: 1))
        m.emissiveIntensity = 1.4
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        m.faceCulling = .none
        return m
    }

    /// "FWS clear": translucent grey-red.
    static func fwsClear(opacity: Float = 0.25) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(white: 0.68, alpha: 1))
        m.metallic = .init(floatLiteral: 0.28)
        m.roughness = .init(floatLiteral: 0.8)
        m.emissiveColor = .init(color: UIColor(red: 1, green: 0.1, blue: 0.05, alpha: 1))
        m.emissiveIntensity = 0.5
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        m.faceCulling = .none
        return m
    }

    /// "FWS Emissive": warm orange glow, used on the tines.
    static func fwsEmissive() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.29, green: 0.0, blue: 0.0, alpha: 1))
        m.roughness = .init(floatLiteral: 0.9)
        m.emissiveColor = .init(color: UIColor(red: 1, green: 0.33, blue: 0.08, alpha: 1))
        m.emissiveIntensity = 1.6
        return m
    }

    /// "Emissive": plain white glow (the poke cube, hand markers).
    static func emissiveWhite() -> UnlitMaterial {
        UnlitMaterial(color: .white)
    }

    /// "Emissive 1": faint grey ghost material.
    static func ghost(opacity: Float = 0.12) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .white)
        m.roughness = .init(floatLiteral: 0.2)
        m.emissiveColor = .init(color: UIColor(white: 0.5, alpha: 1))
        m.emissiveIntensity = 1
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        m.faceCulling = .none
        return m
    }

    /// The seven strata layers alternate between the two "FWS" looks so the
    /// stack reads as distinct sheets when you look through it edge-on.
    static func strataLayer(index: Int) -> PhysicallyBasedMaterial {
        switch index % 3 {
        case 0: return fwsClearBlue(opacity: 0.22)
        case 1: return fwsClear(opacity: 0.2)
        default: return fwsClearBlue(opacity: 0.14)
        }
    }
}
