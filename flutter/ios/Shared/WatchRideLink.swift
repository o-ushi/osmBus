import Foundation

/// iPhone と Apple Watch の間でやり取りする型。Runner と osmBusWatch の両ターゲットに入る。
/// iPhone（Flutter の `TripController`）が正で、Watch は表示・長押し・手首のバイブだけを担当する。

/// iPhone → Watch。`updateApplicationContext` で送る乗車状態の写し（Dart の `WatchLink.snapshotOf`）。
struct WatchRideSnapshot: Codable, Equatable, Sendable {
    /// 乗車中か。
    var isRiding: Bool
    /// 今乗っているバス番号。
    var busNumber: String?
    /// 乗車中のみ。今のレグの直後のバスの番号。直通・最終区間・路線図から乗った場合は nil。
    var nextTransferBusNumber: String?
    /// 未乗車のみ。長押しで乗る番号（直前の乗換先、無ければ判定で乗れると決まった 1 系統）。
    var boardBusNumber: String?
    /// 残り距離の文字。iPhone の距離バッジと同じ（`400 m`、`1.2 km`）。
    var distanceText: String?

    static let idle = WatchRideSnapshot(
        isRiding: false,
        busNumber: nil,
        nextTransferBusNumber: nil,
        boardBusNumber: nil,
        distanceText: nil
    )
}

/// iPhone → Watch。距離アラートの手首バイブ。`count` はチャイムの順位（1 が一番遠いリング）。
struct WatchAlertHaptic: Codable, Equatable, Sendable {
    var id: UUID
    var count: Int
    var firedAt: Date
}

/// Watch → iPhone。バス番号の長押し。
struct WatchBusLongPress: Codable, Equatable, Sendable {
    var busNumber: String
}

/// WatchConnectivity の辞書に載せるキーと、Codable ⇄ Data の変換。
enum WatchRideLink {
    static let snapshotKey = "rideSnapshot"
    static let alertKey = "alertHaptic"
    static let longPressKey = "busLongPress"

    /// これより遅れて届いたアラートの触覚は捨てる。
    static let maxAlertDelay: TimeInterval = 15

    static func encode<T: Encodable>(_ value: T, key: String) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return [key: data]
    }

    static func decode<T: Decodable>(_ type: T.Type, key: String, from dictionary: [String: Any]) -> T? {
        guard let data = dictionary[key] as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
