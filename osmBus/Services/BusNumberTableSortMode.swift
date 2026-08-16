import Foundation

/// トップ画面のバス番号表の並び方。
enum BusNumberTableSortMode: String, CaseIterable, Identifiable {
    static let storageKey = "osmBus.busNumberTableSortMode"

    /// 方向ごとの行 × 乗換数の列 (既定・従来仕様)。
    case byDirection
    /// 方向でグループ化せず、徒歩距離 (同じなら乗車距離) 順にフラットに並べる。
    case byDistance
    /// 乗換回数でグループ化し、各グループ内は距離順。
    case byTransferCount

    var id: String { rawValue }

    var settingsTitleKey: String {
        switch self {
        case .byDirection: return "表の並び_方向基準"
        case .byDistance: return "表の並び_距離基準"
        case .byTransferCount: return "表の並び_乗換回数基準"
        }
    }

    static var current: BusNumberTableSortMode {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? byDirection.rawValue
        return BusNumberTableSortMode(rawValue: raw) ?? .byDirection
    }
}

/// 距離基準 (BusNumberTableSortMode.byDistance) のときだけ使う、距離の測り方。
enum BusNumberTableDistanceMetric: String, CaseIterable, Identifiable {
    static let storageKey = "osmBus.busNumberTableDistanceMetric"

    /// 徒歩合計 (乗車+乗換+降車) を優先し、同じならバス移動距離(道なり)で判定 (既定)。
    case walkPriority
    /// バス移動距離(道なり) + 徒歩合計 の単純合計で判定。
    case totalDistance

    var id: String { rawValue }

    var settingsTitleKey: String {
        switch self {
        case .walkPriority: return "距離基準_歩行距離優先"
        case .totalDistance: return "距離基準_合計距離"
        }
    }

    static var current: BusNumberTableDistanceMetric {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? walkPriority.rawValue
        return BusNumberTableDistanceMetric(rawValue: raw) ?? .walkPriority
    }
}
