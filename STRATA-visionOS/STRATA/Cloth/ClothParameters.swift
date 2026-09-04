import simd

/// Tunable behaviour of one cloth sheet.
///
/// The defaults and the presets below are transcribed from the Unity `Cloth`
/// components in `10-strata.unity`. Unity's cloth has no gravity in STRATA
/// (`UseGravity = 0`) and relies on tethers to float back into shape, which is
/// what `restSpring` reproduces here: every particle is pulled back toward its
/// rest position, so an untouched sheet always settles flat (and therefore
/// silent).
struct ClothParameters {
    /// How strongly structural + shear constraints are enforced, 0...1.
    /// Unity `StretchingStiffness`.
    var stretchStiffness: Float = 0.5

    /// How strongly bending constraints are enforced, 0...1.
    /// Unity `BendingStiffness`.
    var bendStiffness: Float = 0.5

    /// Fraction of velocity lost per 1/60 s. Unity `Damping`, same scale.
    var damping: Float = 0.2

    /// Acceleration per metre of displacement pulling particles back to rest.
    /// Replaces Unity tethers. Higher = snappier return, tighter feel.
    var restSpring: Float = 6

    /// World-space gravity. STRATA cloths float (Unity `UseGravity = 0`).
    var gravity: SIMD3<Float> = .zero

    /// Extra collision radius added around each hand sphere, metres.
    var thickness: Float = 0.008

    /// 0 = frictionless sliding over hands, 1 = particles stick to the hand.
    /// Unity `Friction`.
    var friction: Float = 0.6

    /// Fixed physics rate. Unity `SolverFrequency`.
    var solverFrequency: Float = 120

    /// Gauss–Seidel iterations per substep.
    var iterations: Int = 4

    /// Guard against spiral-of-death when a frame hitches.
    var maxSubstepsPerFrame: Int = 4

    /// Which particles are held fixed in place.
    var pinning: Pinning = .none

    enum Pinning {
        case none
        case topEdge
        case corners
        case leftEdge
    }
}

extension ClothParameters {
    /// The seven thin "strata" layers. Unity: stretch 0.12, bend 1, damping 0.2.
    static let strataLayer = ClothParameters(
        stretchStiffness: 0.35,
        bendStiffness: 0.9,
        damping: 0.2,
        restSpring: 10,
        thickness: 0.006,
        friction: 0.7
    )

    /// "secondary melody cloth": stiff and quick. Unity: stretch 0.99, damping 0.07.
    static let melody = ClothParameters(
        stretchStiffness: 0.95,
        bendStiffness: 0.9,
        damping: 0.07,
        restSpring: 14,
        friction: 0.5
    )

    /// The lowpass cloth next to the melody cloth (same Unity settings as melody).
    static let lowpass = melody

    /// The big 1.25 m "plane suspended" curtain: stiffness 0, damping 1.
    /// Very floppy, very slow to settle.
    static let curtain = ClothParameters(
        stretchStiffness: 0.15,
        bendStiffness: 0.05,
        damping: 0.45,
        restSpring: 3.5,
        thickness: 0.012,
        friction: 0.9,
        iterations: 3
    )

    /// The reverb wall on the opposite side of the curtain.
    static let wall = ClothParameters(
        stretchStiffness: 0.4,
        bendStiffness: 0.3,
        damping: 0.3,
        restSpring: 4,
        friction: 0.7
    )

    /// Intro-scene sheets around the poke cube.
    static let intro = ClothParameters(
        stretchStiffness: 0.5,
        bendStiffness: 0.5,
        damping: 0.15,
        restSpring: 8,
        friction: 0.6
    )
}
