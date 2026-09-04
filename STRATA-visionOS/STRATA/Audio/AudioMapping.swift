import Foundation

/// The displacement → audio parameter curves from the original Unity scripts,
/// transcribed verbatim. All take the cloth bounding-box half extent along the
/// sheet normal (metres) and the script's `inputScaling` (15 in every scene).
enum AudioMapping {
    /// `ClothDisplacementSurfacing` / `StrataDisplacement*` / `WallDisplacementSurfacing`:
    /// `80 * (tanh(input * k) - 1)` → decibels in -80...0.
    static func volumeDecibels(extent: Float, inputScaling: Float = 15) -> Float {
        80 * (tanhf(extent * inputScaling) - 1)
    }

    /// `ClothDisplacementLowpass` / `StrataDisplacementLowpass`:
    /// `-highCap * (tanh(input * k) - 1) + lowCap` → cutoff in Hz, lowCap...lowCap+highCap.
    static func lowpassHertz(extent: Float, inputScaling: Float = 15,
                             lowCap: Float = 60, highCap: Float = 10_000) -> Float {
        -highCap * (tanhf(extent * inputScaling) - 1) + lowCap
    }

    /// `WallDisplacementReverb`: `lowCap * (tanh((input - offset) * k) - 1) + highCap`.
    /// In Unity the result was a reverb level in millibels (-10000...0). Here it is
    /// normalised to a 0...1 wet amount.
    static func reverbWet(extent: Float, inputScaling: Float = 15, offset: Float = 0) -> Float {
        let millibels = -10_000 * (tanhf((extent - offset) * inputScaling) - 1) + 0
        return max(0, min(1, 1 + millibels / 10_000))
    }

    /// `HeadVelocitySurfacing`: `minimumVolume * (tanh(speed) - 1)` → dB in -30...0.
    static func headVelocityDecibels(speed: Float, minimumVolume: Float = 30) -> Float {
        minimumVolume * (tanhf(speed) - 1)
    }

    static func linearGain(decibels: Float) -> Float {
        decibels <= -80 ? 0 : powf(10, decibels / 20)
    }
}

/// One-pole smoother so per-frame parameter writes don't zipper.
struct Smoothed {
    private(set) var value: Float
    var target: Float
    /// Seconds to move ~63% of the way to the target.
    var timeConstant: Float

    init(_ initial: Float, timeConstant: Float = 0.05) {
        value = initial
        target = initial
        self.timeConstant = timeConstant
    }

    mutating func advance(_ dt: Float) -> Float {
        guard timeConstant > 0 else { value = target; return value }
        let alpha = 1 - expf(-dt / timeConstant)
        value += (target - value) * alpha
        return value
    }

    mutating func snap(to v: Float) {
        value = v
        target = v
    }
}
