import AVFoundation
import AudioToolbox
import UIKit
import os.log

final class StopAlertPlayer: @unchecked Sendable {
    static let shared = StopAlertPlayer()
    // 連続再生時は前の再生がまだ鳴り終わっていないうちに次の再生を開始することがあるため、
    // 単一の var で保持すると前のプレイヤーの参照が失われて再生途中に解放され、音量が
    // 落ちたように聞こえる不具合の原因になっていた。再生中のプレイヤーは全て保持する。
    private var activePlayers: [AVAudioPlayer] = []
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
        let fallback = 0.95
        guard let url = AlertSoundCatalog.fileURL(for: StopAlertSettings.soundID),
              let duration = try? AVAudioPlayer(contentsOf: url).duration,
              duration > 0
        else { return fallback }
        // 余白は最小限にする。以前は 0.15 秒の余白に加えて毎回 AVAudioSession を
        // activate/deactivate していたオーバーヘッドが重なり、体感の間隔が間延びしていた。
        // セッションの activate/deactivate をシーケンス単位にまとめたことで余白を詰められる。
        return max(duration + 0.05, fallback)
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
                // 連続再生中(前の音がまだ鳴っている間)は毎回 setCategory/setActive をやり直さない。
                // 再アクティブ化のたびに発生するオーディオルートの再構成が、鳴っている途中の音を
                // 一瞬減衰させたり、無音のギャップを余分に生んだりする原因になっていた。
                if activePlayers.isEmpty {
                    activateSession(category: .playback)
                }
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = followsSystem ? 1.0 : Float(volume)
                player.delegate = playerDelegate
                let started = player.play()
                activePlayers.append(player)  // 再生終了まで全プレイヤーを保持する
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

    fileprivate func playerDidFinish(_ player: AVAudioPlayer) {
        activePlayers.removeAll { $0 === player }
        // シーケンス中の他の再生がまだ残っている場合はセッションを解放しない
        // (解放すると、再生中の他のプレイヤーが一瞬減衰・中断して聞こえることがある)。
        guard activePlayers.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            StopAlertPlayer.shared.playerDidFinish(player)
        }
    }
}
