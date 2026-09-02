import AVFoundation
import Foundation

/// Identifies a long-running stem in the mix (one per cloth instrument).
enum StemID: String, CaseIterable {
    case strata1, strata2, strata3, strata4
    case melody, curtain
    case introSheet
    case background
}

/// The AVAudioEngine graph, mirroring the Unity `Mixer1` layout:
///
///     Master ─ lowpass (GlobalLowpass) ─ reverb (MasterReverb) ─ out
///       ├─ Background+Head   (Sub1Volume ← head velocity; terroir parts, spawn song)
///       ├─ Strata ─ reverb ─ lowpass (StrataLowpass)
///       │    └─ Strata1..4   (Strata*Volume ← layer displacement)
///       └─ Cloths
///            ├─ Cloth1..     (Cloth*Volume ← displacement) ─┐ send
///            └─ ReturnoftheCloths (echo) ◄──────────────────┘
///
/// Every stem is an `AVAudioPlayerNode → AVAudioUnitVarispeed → gain mixer`.
/// Varispeed reproduces Unity's `AudioSource.pitch` (a playback-rate change).
/// All stems are started against one shared host time so they stay locked.
@MainActor
final class StemEngine {
    private final class Stem {
        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        let gain = AVAudioMixerNode()
        let file: AVAudioFile
        var level = Smoothed(-80, timeConstant: 0.04)
        init(file: AVAudioFile) { self.file = file }
    }

    private let engine = AVAudioEngine()
    private let busFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    // Buses
    private let master = AVAudioMixerNode()
    private let masterLowpass = AVAudioUnitEQ(numberOfBands: 1)
    private let masterReverb = AVAudioUnitReverb()
    private let backgroundBus = AVAudioMixerNode()
    private let strataBus = AVAudioMixerNode()
    private let strataReverb = AVAudioUnitReverb()
    private let strataLowpass = AVAudioUnitEQ(numberOfBands: 1)
    private let clothsBus = AVAudioMixerNode()
    private let echoSend = AVAudioMixerNode()
    private let clothEcho = AVAudioUnitDelay()
    private let echoReturn = AVAudioMixerNode()

    private var stems: [StemID: Stem] = [:]
    private var oneShotPool: [AVAudioPlayerNode] = []
    private var oneShotFiles: [String: AVAudioFile] = [:]

    private var globalLowpassHz = Smoothed(60, timeConstant: 0.08)
    private var strataLowpassHz = Smoothed(60, timeConstant: 0.08)
    private var masterReverbWet = Smoothed(0, timeConstant: 0.2)
    private var backgroundDb = Smoothed(-30, timeConstant: 0.3)

    private(set) var isRunning = false

    init() {
        buildGraph()
    }

    // MARK: - Graph

    private func buildGraph() {
        for node in [master, masterLowpass, masterReverb, backgroundBus, strataBus, strataReverb,
                     strataLowpass, clothsBus, echoSend, clothEcho, echoReturn] as [AVAudioNode] {
            engine.attach(node)
        }

        masterLowpass.bands[0].filterType = .lowPass
        masterLowpass.bands[0].frequency = 60
        masterLowpass.bands[0].bandwidth = 0.7
        masterLowpass.bands[0].bypass = false

        masterReverb.loadFactoryPreset(.largeHall2)
        masterReverb.wetDryMix = 0

        strataReverb.loadFactoryPreset(.cathedral)
        strataReverb.wetDryMix = 35

        strataLowpass.bands[0].filterType = .lowPass
        strataLowpass.bands[0].frequency = 60
        strataLowpass.bands[0].bandwidth = 0.7
        strataLowpass.bands[0].bypass = false

        clothEcho.delayTime = 0.375
        clothEcho.feedback = 40
        clothEcho.lowPassCutoff = 5_000
        clothEcho.wetDryMix = 100
        echoReturn.outputVolume = AudioMapping.linearGain(decibels: -14)

        // Master chain
        engine.connect(master, to: masterLowpass, format: busFormat)
        engine.connect(masterLowpass, to: masterReverb, format: busFormat)
        engine.connect(masterReverb, to: engine.mainMixerNode, format: busFormat)

        // Sub buses into master
        engine.connect(backgroundBus, to: master, format: busFormat)
        engine.connect(strataBus, to: strataReverb, format: busFormat)
        engine.connect(strataReverb, to: strataLowpass, format: busFormat)
        engine.connect(strataLowpass, to: master, format: busFormat)
        engine.connect(clothsBus, to: master, format: busFormat)
        engine.connect(echoSend, to: clothEcho, format: busFormat)
        engine.connect(clothEcho, to: echoReturn, format: busFormat)
        engine.connect(echoReturn, to: master, format: busFormat)

        backgroundBus.outputVolume = AudioMapping.linearGain(decibels: -30)

        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: backgroundBus, format: busFormat)
            oneShotPool.append(p)
        }
        engine.prepare()
    }

    enum Bus { case strata, cloths, background }

    /// Load a stem and wire it into a bus. Missing files are logged, not fatal,
    /// so the experience still runs before `Scripts/import-audio.sh` has been run.
    func load(_ id: StemID, file name: String, rate: Float = 1, bus: Bus, echoSend: Bool = false) {
        guard let file = AudioAssets.openFile(named: name) else {
            print("STRATA: missing stem '\(name)' for \(id)")
            return
        }
        let stem = Stem(file: file)
        engine.attach(stem.player)
        engine.attach(stem.varispeed)
        engine.attach(stem.gain)
        stem.varispeed.rate = rate
        stem.gain.outputVolume = 0

        engine.connect(stem.player, to: stem.varispeed, format: file.processingFormat)
        engine.connect(stem.varispeed, to: stem.gain, format: file.processingFormat)

        let target: AVAudioMixerNode
        switch bus {
        case .strata: target = strataBus
        case .cloths: target = clothsBus
        case .background: target = backgroundBus
        }
        if echoSend {
            let points = [
                AVAudioConnectionPoint(node: target, bus: target.nextAvailableInputBus),
                AVAudioConnectionPoint(node: self.echoSend, bus: self.echoSend.nextAvailableInputBus),
            ]
            engine.connect(stem.gain, to: points, fromBus: 0, format: busFormat)
        } else {
            engine.connect(stem.gain, to: target, format: busFormat)
        }
        stems[id] = stem
    }

    func preloadOneShot(file name: String) {
        guard oneShotFiles[name] == nil, let file = AudioAssets.openFile(named: name) else { return }
        oneShotFiles[name] = file
    }

    // MARK: - Transport

    func start() {
        guard !isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isRunning = true
        } catch {
            print("STRATA: audio engine failed to start: \(error)")
        }
    }

    /// Schedule every loaded stem from the top, sample-locked to a shared start
    /// time a little in the future so the players all begin on the same render cycle.
    func playAllStems(from ids: [StemID]? = nil, delay: TimeInterval = 0.2) {
        guard isRunning else { return }
        let hostStart = AVAudioTime.hostTime(forSeconds: AVAudioTime.seconds(forHostTime: mach_absolute_time()) + delay)
        let startTime = AVAudioTime(hostTime: hostStart)
        for (id, stem) in stems where ids == nil || ids!.contains(id) {
            stem.player.stop()
            stem.file.framePosition = 0
            stem.player.scheduleFile(stem.file, at: nil)
            stem.player.play(at: startTime)
        }
    }

    func stopAllStems() {
        for stem in stems.values {
            stem.player.stop()
            stem.level.snap(to: -80)
            stem.gain.outputVolume = 0
        }
    }

    /// Fire a non-spatial one-shot on the background bus (the hand-triggered
    /// `terroir part a/b` stems). Returns false when no pool player is free.
    @discardableResult
    func playOneShot(file name: String, gainDb: Float = 0) -> Bool {
        guard isRunning, let file = oneShotFiles[name] ?? AudioAssets.openFile(named: name) else { return false }
        oneShotFiles[name] = file
        guard let player = oneShotPool.first(where: { !$0.isPlaying }) else { return false }
        player.volume = AudioMapping.linearGain(decibels: gainDb)
        file.framePosition = 0
        player.scheduleFile(file, at: nil)
        player.play()
        return true
    }

    // MARK: - Parameters (targets; smoothed in `advance`)

    func setStemLevel(_ id: StemID, decibels: Float) {
        stems[id]?.level.target = decibels.clamped(-80, 0)
    }

    func setGlobalLowpass(hertz: Float) { globalLowpassHz.target = hertz.clamped(40, 20_000) }
    func setStrataLowpass(hertz: Float) { strataLowpassHz.target = hertz.clamped(40, 20_000) }
    func setMasterReverb(wet: Float) { masterReverbWet.target = wet.clamped(0, 1) }
    func setBackgroundLevel(decibels: Float) { backgroundDb.target = decibels.clamped(-80, 0) }

    /// Called once per frame to move smoothed parameters toward their targets.
    func advance(deltaTime: Float) {
        guard isRunning else { return }
        for stem in stems.values {
            let db = stem.level.advance(deltaTime)
            stem.gain.outputVolume = AudioMapping.linearGain(decibels: db)
        }
        masterLowpass.bands[0].frequency = globalLowpassHz.advance(deltaTime)
        strataLowpass.bands[0].frequency = strataLowpassHz.advance(deltaTime)
        masterReverb.wetDryMix = masterReverbWet.advance(deltaTime) * 60
        backgroundBus.outputVolume = AudioMapping.linearGain(decibels: backgroundDb.advance(deltaTime))
    }
}

/// Locates audio in the bundle. Stems are imported as ALAC `.m4a` by
/// `Scripts/import-audio.sh`; the loader also accepts the original formats so
/// files dropped in by hand still work.
enum AudioAssets {
    static let extensions = ["m4a", "caf", "aif", "aiff", "wav", "mp3"]

    static func url(named name: String) -> URL? {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio") { return url }
        }
        return nil
    }

    static func openFile(named name: String) -> AVAudioFile? {
        guard let url = url(named: name) else { return nil }
        return try? AVAudioFile(forReading: url)
    }
}
