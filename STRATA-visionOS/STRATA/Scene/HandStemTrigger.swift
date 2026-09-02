import Foundation

/// Unity `PlayHandSound2` on the `HandCube` attached to each Leap hand: when the
/// hand enters a sheet tagged "Cloth", fire that hand's `terroir` part.
/// Left hand carries part A, right hand part B.
@MainActor
final class HandStemTrigger {
    private var wasInside: [HandPose.Side: Bool] = [.left: false, .right: false]
    private var lastFired: [HandPose.Side: Float] = [:]
    private var clock: Float = 0

    static let files: [HandPose.Side: String] = [
        .left: "terroir part a",
        .right: "terroir part b",
    ]

    func update(deltaTime: Float,
                hands: [(HandPose.Side, [SphereCollider])],
                instruments: [ClothInstrument],
                audio: StemEngine) {
        clock += deltaTime
        for (side, spheres) in hands {
            let inside = instruments.contains { $0.isHandTrigger && $0.containsAny(spheres) }
            if inside && !(wasInside[side] ?? false) {
                let last = lastFired[side] ?? -.greatestFiniteMagnitude
                if clock - last >= StrataLayout.handStemCooldown, let file = Self.files[side] {
                    if audio.playOneShot(file: file, gainDb: side == .left ? 0 : -3) {
                        lastFired[side] = clock
                    }
                }
            }
            wasInside[side] = inside
        }
    }

    func reset() {
        wasInside = [.left: false, .right: false]
        lastFired = [:]
        clock = 0
    }
}
