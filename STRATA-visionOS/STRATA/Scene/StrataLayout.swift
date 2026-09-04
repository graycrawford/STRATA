import simd

/// Where everything lives, in metres, in the immersive space's coordinate
/// system: origin on the floor under the viewer when the space opens, +y up,
/// -z straight ahead.
///
/// The Unity scene put the strata stack off to the viewer's left with the
/// sheets facing sideways. Here the stack sits in front at chest height with
/// the sheets facing the viewer, so you push a hand *forward* through the
/// layers; the two side pieces (curtain, reverb wall) stay left and right as
/// they were. Every number here is a starting point to tune on-device.
enum StrataLayout {
    // MARK: Strata stack — 7 thin sheets, each a stem

    struct Layer {
        var stem: StemID?
        var rate: Float
        var drivesStrataLowpass: Bool
        var fileName: String?
    }

    static let stackCenter = SIMD3<Float>(0, 1.25, -0.55)
    static let stackSheetSize: Float = 0.30
    static let stackSpacing: Float = 0.06
    static let stackResolution = 33

    /// Ordered nearest → farthest from the viewer. Stem rates are the Unity
    /// `AudioSource.pitch` values on the `volume+emitter*` objects.
    static let layers: [Layer] = [
        Layer(stem: .strata1, rate: 1.0, drivesStrataLowpass: false, fileName: "backing noise"),
        Layer(stem: nil, rate: 1, drivesStrataLowpass: false, fileName: nil),
        Layer(stem: .strata3, rate: 0.6, drivesStrataLowpass: false, fileName: "backing noise"),
        Layer(stem: nil, rate: 1, drivesStrataLowpass: true, fileName: nil),
        Layer(stem: nil, rate: 1, drivesStrataLowpass: false, fileName: nil),
        Layer(stem: .strata4, rate: 0.8, drivesStrataLowpass: false, fileName: "backing noise"),
        Layer(stem: .strata2, rate: 0.7, drivesStrataLowpass: false, fileName: "backing noise"),
    ]

    // MARK: Melody + lowpass cloths (low, in front)

    static let melodyCenter = SIMD3<Float>(-0.32, 0.98, -0.5)
    static let lowpassCenter = SIMD3<Float>(0.32, 0.98, -0.5)
    static let smallSheetSize: Float = 0.30
    static let smallSheetResolution = 25

    // MARK: Curtain (left) and reverb wall (right)

    static let curtainCenter = SIMD3<Float>(-1.0, 1.45, -0.35)
    static let curtainSize: Float = 1.25
    static let curtainResolution = 41

    static let wallCenter = SIMD3<Float>(1.0, 1.45, -0.35)
    static let wallSize: Float = 1.0
    static let wallResolution = 33

    // MARK: Tine field (16 x 4 capsules, low right)

    static let tineFieldCenter = SIMD3<Float>(0.45, 0.78, -0.35)
    static let tineColumns = 16
    static let tineRows = 4
    static let tineSpacingX: Float = 0.045
    static let tineSpacingZ: Float = 0.07
    static let tineHeight: Float = 0.07
    static let tineRadius: Float = 0.006

    // MARK: Intro

    static let pokeCubeCenter = SIMD3<Float>(0.0, 1.15, -0.45)
    static let pokeCubeSize: Float = 0.06
    static let introSheetCenter = SIMD3<Float>(0.0, 1.2, -0.85)
    static let introSheetSize: Float = 0.6
    static let introSheetResolution = 33

    // MARK: Timeline (seconds, from the Unity `ResetTimer` / `GlobalShrink`)

    static let experienceDuration: Float = 235
    static let shrinkStart: Float = 169.5
    static let shrinkEnd: Float = 233
    static let shrinkScale: Float = 0.05

    // MARK: Interaction

    /// Minimum gap between re-triggering a hand's `terroir` part.
    static let handStemCooldown: Float = 12
    /// Probability that a tine is voiced at all (Unity `PlayTine.prob`).
    static let tineVoicedProbability: Float = 1.0
}
