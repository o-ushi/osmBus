import Flutter
import Foundation
import WatchConnectivity

/// Apple Watch との橋渡し。Dart の `WatchLink` から乗車状態の写しと距離アラートを受けて Watch へ送り、
/// Watch のバス番号の長押しを Dart へ渡す。判断はすべて Dart 側（`TripController.longPressBusNumber`）。
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private var channel: FlutterMethodChannel?
    /// 最後に Dart から届いた写し。セッションの有効化が後から終わっても送れるよう覚えておく。
    private var latestSnapshot: WatchRideSnapshot?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    /// 起動時に有効化する。Watch を開いた直後に最新の写しが届くようにするため。
    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "osmbus/watch", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(nil) }
            switch call.method {
            case "snapshot":
                if let snapshot = Self.snapshot(from: call.arguments) {
                    self.latestSnapshot = snapshot
                    self.pushSnapshot()
                }
                result(nil)
            case "alert":
                if let count = (call.arguments as? NSNumber)?.intValue {
                    self.sendAlert(count: count)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        self.channel = channel
    }

    private static func snapshot(from arguments: Any?) -> WatchRideSnapshot? {
        guard let map = arguments as? [String: Any] else { return nil }
        func string(_ key: String) -> String? { map[key] as? String }
        return WatchRideSnapshot(
            isRiding: (map["isRiding"] as? Bool) ?? false,
            busNumber: string("busNumber"),
            nextTransferBusNumber: string("nextTransferBusNumber"),
            boardBusNumber: string("boardBusNumber"),
            distanceText: string("distanceText")
        )
    }

    private var canTalkToWatch: Bool {
        guard let session else { return false }
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    private func pushSnapshot() {
        guard canTalkToWatch, let session, let snapshot = latestSnapshot,
              let context = WatchRideLink.encode(snapshot, key: WatchRideLink.snapshotKey) else { return }
        try? session.updateApplicationContext(context)
    }

    /// Watch アプリが前面で届くときだけ鳴る。届かなかった分は後から送らない。
    private func sendAlert(count: Int) {
        guard canTalkToWatch, let session, session.isReachable,
              let message = WatchRideLink.encode(
                  WatchAlertHaptic(id: UUID(), count: count, firedAt: Date()),
                  key: WatchRideLink.alertKey
              ) else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    private func handleLongPress(_ press: WatchBusLongPress) {
        channel?.invokeMethod("longPress", arguments: press.busNumber)
    }
}

extension WatchBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.pushSnapshot() }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // Watch アプリを入れた直後にも最新の写しを渡す。
        DispatchQueue.main.async { self.pushSnapshot() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // 別の Watch に切り替えたとき。新しい Watch のために有効化し直す。
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let press = WatchRideLink.decode(WatchBusLongPress.self, key: WatchRideLink.longPressKey, from: message) else {
            return
        }
        DispatchQueue.main.async { self.handleLongPress(press) }
    }
}
