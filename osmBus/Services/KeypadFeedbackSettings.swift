import UIKit
import AVFoundation

// MARK: - Haptic intensity

enum KeypadHapticIntensity: String, CaseIterable, Identifiable {
    case light = "light"
    case medium = "medium"
    case strong = "strong"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .light:  return "キーフィードバック_弱め"
        case .medium: return "キーフィードバック_普通"
        case .strong: return "キーフィードバック_強め"
        }
    }

    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:  return .light
        case .medium: return .medium
        case .strong: return .heavy
        }
    }
}

// MARK: - Manager (osmSolver の HapticManager 相当)

/// AVAudioEngine でサイン波クリック音を生成。システム音量に非依存。
final class KeypadHapticManager {
    static let shared = KeypadHapticManager()

    // UserDefaults キー
    static let hapticEnabledKey   = "osmBus_haptic_enabled"
    static let hapticIntensityKey = "osmBus_haptic_intensity"
    static let soundEnabledKey    = "osmBus_sound_enabled"
    static let soundVolumeKey     = "osmBus_sound_volume"

    private let audioEngine = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    private var audioBuffer: AVAudioPCMBuffer?
    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]

    private init() {
        for style: UIImpactFeedbackGenerator.FeedbackStyle in [.light, .medium, .heavy] {
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.prepare()
            impactGenerators[style] = gen
        }
        setupAudioSession()
        setupAudioEngine()
    }

    // MARK: Public

    func triggerKeyTap() {
        let ud = UserDefaults.standard
        if ud.bool(forKey: Self.hapticEnabledKey) {
            let raw = ud.string(forKey: Self.hapticIntensityKey) ?? "medium"
            playHaptic(KeypadHapticIntensity(rawValue: raw) ?? .medium)
        }
        if ud.bool(forKey: Self.soundEnabledKey) {
            let vol = ud.double(forKey: Self.soundVolumeKey)
            playSound(volume: vol > 0 ? vol : 0.5)
        }
    }

    func triggerEnterKey() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func previewSound(volume: Double) { playSound(volume: volume) }
    func previewHaptic(_ intensity: KeypadHapticIntensity) { playHaptic(intensity) }

    static func registerDefaults() {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        UserDefaults.standard.register(defaults: [
            hapticEnabledKey:   !isIPad,
            hapticIntensityKey: "medium",
            soundEnabledKey:    false,
            soundVolumeKey:     0.5,
        ])
    }

    // MARK: Private – audio

    private func setupAudioSession() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try s.setActive(true)
        } catch {}
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        let fmt = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioBuffer = makeClickBuffer(format: fmt)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: fmt)
        try? audioEngine.start()
    }

    private func makeClickBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate  = format.sampleRate
        let frameCount  = UInt32(sampleRate * 0.02)   // 20 ms
        let frequency   = 1200.0
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let ch  = buf.floatChannelData else { return nil }
        buf.frameLength = frameCount
        for c in 0..<Int(format.channelCount) {
            for i in 0..<Int(frameCount) {
                let p = Double(i) / Double(frameCount)
                let env = pow(1.0 - p, 2.0)
                ch[c][i] = Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate) * env)
            }
        }
        return buf
    }

    private func playHaptic(_ intensity: KeypadHapticIntensity) {
        let style = intensity.impactStyle
        guard let gen = impactGenerators[style] else { return }
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { gen.prepare() }
    }

    private func playSound(volume: Double) {
        guard volume > 0 else { return }
        ensureAudioSessionActive()
        if !audioEngine.isRunning {
            try? audioEngine.start()
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard let buf = audioBuffer else { return }
        playerNode.volume = Float(volume)
        audioEngine.mainMixerNode.outputVolume = 1.0
        playerNode.stop()
        playerNode.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        playerNode.play()
    }

    @discardableResult
    private func ensureAudioSessionActive() -> Bool {
        let s = AVAudioSession.sharedInstance()
        guard s.category != .playback else { return false }
        do {
            if audioEngine.isRunning { audioEngine.stop() }
            try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try s.setActive(true)
            try audioEngine.start()
            return true
        } catch { return false }
    }
}
