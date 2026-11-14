import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// Watch 側の受け口。iPhone から届いた乗車状態の写しを持ち、距離アラートの触覚を鳴らし、
/// バス番号の長押しを iPhone へ送る。経路計算・測位は持たない。
@MainActor
@Observable
final class WatchRideStore: NSObject {
    static let shared = WatchRideStore()

    private(set) var snapshot: WatchRideSnapshot = .idle

    /// 再生中の触覚の列。次のアラートが来たら止めて、新しい回数だけ鳴らす。
    @ObservationIgnored private var hapticTask: Task<Void, Never>?
    @ObservationIgnored private var lastAlertID: UUID?

    /// 1 回の `.notification` の間隔。
    private static let hapticInterval: Duration = .milliseconds(800)

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// バス番号の長押し。受け付けたことだけクリック触覚で返し、判断は iPhone に任せる。
    func sendLongPress(busNumber: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isReachable,
              let message = WatchRideLink.encode(
                  WatchBusLongPress(busNumber: busNumber),
                  key: WatchRideLink.longPressKey
              )
        else { return }
        WKInterfaceDevice.current().play(.click)
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    fileprivate func apply(_ snapshot: WatchRideSnapshot) {
        self.snapshot = snapshot
    }

    /// `count` 回だけ `.notification` を約 0.8 秒空けて鳴らす。`.retry` でまとめない。
    /// 遅れて届いたものは捨て、届かなかった分を後から鳴らすこともしない。
    /// `WKInterfaceDevice.play` はアプリが前面のときだけ鳴る。
    fileprivate func playAlert(_ alert: WatchAlertHaptic) {
        guard alert.id != lastAlertID else { return }
        lastAlertID = alert.id
        guard Date().timeIntervalSince(alert.firedAt) <= WatchRideLink.maxAlertDelay else { return }

        hapticTask?.cancel()
        let count = max(alert.count, 1)
        hapticTask = Task { @MainActor in
            for index in 0..<count {
                if index > 0 {
                    try? await Task.sleep(for: Self.hapticInterval)
                }
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}

extension WatchRideStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // iPhone が最後に送った写しを、開いた直後に出す。
        guard let snapshot = WatchRideLink.decode(
            WatchRideSnapshot.self,
            key: WatchRideLink.snapshotKey,
            from: session.receivedApplicationContext
        ) else { return }
        Task { @MainActor in
            WatchRideStore.shared.apply(snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let snapshot = WatchRideLink.decode(
            WatchRideSnapshot.self,
            key: WatchRideLink.snapshotKey,
            from: applicationContext
        ) else { return }
        Task { @MainActor in
            WatchRideStore.shared.apply(snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let alert = WatchRideLink.decode(
            WatchAlertHaptic.self,
            key: WatchRideLink.alertKey,
            from: message
        ) else { return }
        Task { @MainActor in
            WatchRideStore.shared.playAlert(alert)
        }
    }
}
