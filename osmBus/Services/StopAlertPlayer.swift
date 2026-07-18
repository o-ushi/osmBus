import AVFoundation
import AudioToolbox
import UIKit
import os.log

final class StopAlertPlayer: @unchecked Sendable {
    static let shared = StopAlertPlayer()
    private var audioPlayer: AVAudioPlayer?
    private let playerDelegate = AudioPlayerDelegate()
    // 実際の乗車中に音が鳴らない不具合が繰り返し報告されているため、原因特定用に
    // Console.app (デバイスログ) で追える最小限のログを残す。
    private let logger = Logger(subsystem: "com.osamushikubo.osmBus", category: "StopAlertPlayer")
    private init() {}

    // MARK: - Alert playback

    /// 距離アラート用：通常アラーム音を count 回連続再生する。
    /// 音源自体の長さより間隔が短いと、前の再生の末尾と次の再生の先頭が重なって
    /// 1回分に融合して聞こえてしまうため、間隔はサウンドの実長に合わせて動的に決める。
    func playAlarmTimes(_ count: Int) {
        guard count >= 1 else { return }
        playDistanceAlarmOnce()
        guard count > 1 else { return }
        let interval = alarmInterval()
        for i in 1..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) { [weak self] in
                self?.playDistanceAlarmOnce()
            }
        }
    }

    private func alarmInterval() -> Double {
        // ファイル参照できないサウンド（デフォルトの三連音など）は長さを実測できないため、
        // 余裕を持った間隔にしてオーバーラップによる融合を防ぐ。
        let fallback = 1.05
        guard let url = AlertSoundCatalog.fileURL(for: StopAlertSettings.soundID),
              let duration = try? AVAudioPlayer(contentsOf: url).duration,
              duration > 0
        else { return fallback }
        return max(duration + 0.15, fallback)
    }

    private func playDistanceAlarmOnce() {
        playSound(
            id: StopAlertSettings.soundID,
            followsSystem: StopAlertSettings.soundFollowsSystem,
            volume: StopAlertSettings.soundVolume
        )
    }

    func playVibration() {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch StopAlertSettings.vibrationStyle {
        case .light:  style = .light
        case .medium: style = .medium
        case .heavy:  style = .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: - Preview

    func preview(id: String, followsSystem: Bool, volume: Double) {
        playSound(id: id, followsSystem: followsSystem, volume: volume)
    }

    func previewVibration(_ style: AlertVibrationStyle) {
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:  feedbackStyle = .light
        case .medium: feedbackStyle = .medium
        case .heavy:  feedbackStyle = .heavy
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }

    // MARK: - Private

    private func playSound(id: String, followsSystem: Bool, volume: Double) {
        guard let entry = AlertSoundCatalog.entry(for: id) else {
            logger.error("playSound: unknown sound id=\(id, privacy: .public)")
            return
        }
        logger.notice("playSound start id=\(id, privacy: .public) followsSystem=\(followsSystem) appState=\(UIApplication.shared.applicationState.rawValue)")

        // Always prefer the real audio file over AudioServicesPlaySystemSound: the latter
        // plays at a fixed, very quiet system-effect volume and, for some sound IDs, is
        // silenced to vibration-only depending on the ringer switch. AVAudioPlayer with
        // .playback (mixWithOthers) plays at full/adjustable volume and — since this app
        // declares the "audio" background mode — keeps working while the screen is locked
        // during an actual bus ride, which .ambient does not reliably do.
        // followsSystem only affects volume (system/media volume vs. custom slider); the
        // ringer/silent switch is intentionally overridden so the stop alert isn't missed.
        if let url = AlertSoundCatalog.fileURL(for: id) {
            do {
                activateSession(category: .playback)
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = followsSystem ? 1.0 : Float(volume)
                player.delegate = playerDelegate
                let started = player.play()
                audioPlayer = player  // retain until playback ends
                logger.notice("playSound file=\(url.lastPathComponent, privacy: .public) play()=\(started) volume=\(player.volume) sessionOutputVolume=\(AVAudioSession.sharedInstance().outputVolume) route=\(AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: ","), privacy: .public)")
                return
            } catch {
                logger.error("playSound AVAudioPlayer init failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.notice("playSound: no local file for id=\(id, privacy: .public), falling back to AudioServicesPlaySystemSound(\(entry.systemSoundID))")
        }

        activateSession(category: .ambient)
        AudioServicesPlaySystemSound(entry.systemSoundID)
    }

    private func activateSession(category: AVAudioSession.Category) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            logger.error("activateSession(\(String(describing: category), privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
