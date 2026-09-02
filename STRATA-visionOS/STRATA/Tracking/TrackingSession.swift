import ARKit
import Foundation
import QuartzCore
import simd

/// One tracked hand reduced to the spheres we collide cloth against.
struct HandPose {
    enum Side { case left, right }

    struct Joint {
        var position: SIMD3<Float>
        var radius: Float
        var name: HandSkeleton.JointName
    }

    var side: Side
    var joints: [Joint]
    var palm: SIMD3<Float>
    var indexTip: SIMD3<Float>

    var fingertips: [SIMD3<Float>] {
        joints.filter { Self.tipNames.contains($0.name) }.map(\.position)
    }

    static let tipNames: Set<HandSkeleton.JointName> = [
        .thumbTip, .indexFingerTip, .middleFingerTip, .ringFingerTip, .littleFingerTip,
    ]
}

/// Snapshot of both hands and the head for one frame, in world space.
struct TrackingSnapshot {
    var left: HandPose?
    var right: HandPose?
    var headTransform: simd_float4x4?
    var timestamp: TimeInterval = 0

    var hands: [HandPose] { [left, right].compactMap { $0 } }
}

/// Owns the ARKit session. Hand anchors stream in on a background task; the
/// render loop pulls the latest snapshot with `snapshot()`.
final class TrackingSession {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let worldTracking = WorldTrackingProvider()
    private let lock = NSLock()
    private var latestLeft: HandPose?
    private var latestRight: HandPose?
    private var updateTask: Task<Void, Never>?

    /// Sphere radii per joint, metres. Fingertips are small so a single finger
    /// can pluck a tine; the palm is large so a flat hand shoves a whole sheet.
    private static let jointRadii: [(HandSkeleton.JointName, Float)] = [
        (.thumbTip, 0.010), (.indexFingerTip, 0.009), (.middleFingerTip, 0.009),
        (.ringFingerTip, 0.009), (.littleFingerTip, 0.008),
        (.thumbIntermediateTip, 0.011), (.indexFingerIntermediateTip, 0.010),
        (.middleFingerIntermediateTip, 0.010), (.ringFingerIntermediateTip, 0.010),
        (.littleFingerIntermediateTip, 0.009),
        (.thumbIntermediateBase, 0.012), (.indexFingerIntermediateBase, 0.011),
        (.middleFingerIntermediateBase, 0.011), (.ringFingerIntermediateBase, 0.011),
        (.littleFingerIntermediateBase, 0.010),
        (.indexFingerKnuckle, 0.013), (.middleFingerKnuckle, 0.013),
        (.ringFingerKnuckle, 0.013), (.littleFingerKnuckle, 0.012),
        (.wrist, 0.028),
    ]

    var isSupported: Bool { HandTrackingProvider.isSupported }

    func start() async {
        guard HandTrackingProvider.isSupported else {
            print("STRATA: hand tracking is not supported on this device/simulator")
            return
        }
        do {
            try await session.run([handTracking, worldTracking])
        } catch {
            print("STRATA: ARKit session failed to start: \(error)")
            return
        }
        updateTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            for await update in self.handTracking.anchorUpdates {
                let anchor = update.anchor
                let pose = anchor.isTracked ? Self.pose(from: anchor) : nil
                self.lock.lock()
                switch anchor.chirality {
                case .left: self.latestLeft = pose
                case .right: self.latestRight = pose
                }
                self.lock.unlock()
            }
        }
    }

    func stop() {
        updateTask?.cancel()
        updateTask = nil
        session.stop()
    }

    func snapshot() -> TrackingSnapshot {
        lock.lock()
        let left = latestLeft
        let right = latestRight
        lock.unlock()
        let now = CACurrentMediaTime()
        let head = worldTracking.state == .running
            ? worldTracking.queryDeviceAnchor(atTimestamp: now)?.originFromAnchorTransform
            : nil
        return TrackingSnapshot(left: left, right: right, headTransform: head, timestamp: now)
    }

    private static func pose(from anchor: HandAnchor) -> HandPose? {
        guard let skeleton = anchor.handSkeleton else { return nil }
        let originFromAnchor = anchor.originFromAnchorTransform
        var joints: [HandPose.Joint] = []
        joints.reserveCapacity(jointRadii.count)
        for (name, radius) in jointRadii {
            let joint = skeleton.joint(name)
            guard joint.isTracked else { continue }
            let world = originFromAnchor * joint.anchorFromJointTransform
            joints.append(HandPose.Joint(position: world.translation, radius: radius, name: name))
        }
        guard !joints.isEmpty else { return nil }

        // ARKit has no palm joint; approximate it between wrist and middle knuckle.
        let wrist = originFromAnchor.translation
        let middleKnuckle = (originFromAnchor * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).translation
        let palm = (wrist + middleKnuckle) * 0.5
        joints.append(HandPose.Joint(position: palm, radius: 0.03, name: .wrist))

        let indexTip = (originFromAnchor * skeleton.joint(.indexFingerTip).anchorFromJointTransform).translation
        return HandPose(side: anchor.chirality == .left ? .left : .right,
                        joints: joints, palm: palm, indexTip: indexTip)
    }
}
