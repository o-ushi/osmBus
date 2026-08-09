import Foundation
import AudioToolbox

// MARK: - Sound Catalog

struct AlertSoundEntry: Identifiable, Sendable {
    let id: String
    let nameKey: String
    let systemSoundID: SystemSoundID
    let relativePath: String?  // relative to /System/Library/Audio/UISounds/, nil if not exposed as a plain file (system-only asset)
}

enum AlertSoundCatalog {
    static let all: [AlertSoundEntry] = [
        // 「Tri-tone」「Bell」の実体(Tri-Tone.m4r / Bell.m4r)は ToneLibrary.framework という
        // プライベートフレームワーク内にのみ存在し、公開領域にコピーがないためサードパーティ
        // アプリからは読み込めない(App Store配布を想定するため、抽出して同梱する対応は避けている)。
        // 音色の近い公開システムサウンドで代用する。
        AlertSoundEntry(id: "alarm",   nameKey: "サウンド_三連音",     systemSoundID: 1307, relativePath: "sms-received1.caf"),
        AlertSoundEntry(id: "chime",   nameKey: "サウンド_チャイム",   systemSoundID: 1000, relativePath: "new-mail.caf"),
        AlertSoundEntry(id: "ding",    nameKey: "サウンド_ディン",     systemSoundID: 1001, relativePath: "mail-sent.caf"),
        AlertSoundEntry(id: "message", nameKey: "サウンド_メッセージ", systemSoundID: 1003, relativePath: "ReceivedMessage.caf"),
        AlertSoundEntry(id: "confirm", nameKey: "サウンド_確認音",     systemSoundID: 1393, relativePath: "jbl_confirm.caf"),
        AlertSoundEntry(id: "tock",    nameKey: "サウンド_タック",     systemSoundID: 1104, relativePath: "Tock.aiff"),
        AlertSoundEntry(id: "bell",    nameKey: "サウンド_ベル",       systemSoundID: 1023, relativePath: "Doorbell.caf"),
        // iOS設定 > サウンドと触覚 > 新着メール > クラシック の「Tiptoes」と同一音源。
        // ToneLibrary.framework内のプライベート版とは別に、公開領域の UISounds/New/ にも
        // 実体が存在するため、他エントリと同じ方式でそのまま再生できる。
        AlertSoundEntry(id: "tiptoes", nameKey: "サウンド_つま先",     systemSoundID: 1310, relativePath: "New/Tiptoes.caf"),
    ]

    static let defaultID = "tiptoes"

    static func entry(for id: String) -> AlertSoundEntry? {
        all.first { $0.id == id }
    }

    static func fileURL(for id: String) -> URL? {
        guard let entry = entry(for: id), let relativePath = entry.relativePath else { return nil }
        let path = "/System/Library/Audio/UISounds/\(relativePath)"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}

// MARK: - Vibration Style

enum AlertVibrationStyle: String, CaseIterable, Identifiable {
    case light  = "light"
    case medium = "medium"
    case heavy  = "heavy"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .light:  return "キーフィードバック_弱め"
        case .medium: return "キーフィードバック_普通"
        case .heavy:  return "キーフィードバック_強め"
        }
    }
}

// MARK: - Alert Mode (used for on/off toggles)

enum StopAlertMode: String, CaseIterable, Identifiable {
    case alarm      = "alarm"
    case alert      = "alert"
    case vibration  = "vibration"

    var id: String { rawValue }
    var storageKey: String { "osmBus_alert_\(rawValue)" }

    var defaultEnabled: Bool {
        switch self {
        case .alarm:     return false
        case .alert:     return true
        case .vibration: return true
        }
    }
}

// MARK: - Settings

enum StopAlertSettings {
    static let soundIDKey            = "osmBus_alert_soundID"
    static let followsSystemKey      = "osmBus_alert_followsSystem"
    static let volumeKey             = "osmBus_alert_soundVolume"
    static let vibStyleKey           = "osmBus_alert_vibStyle"

    static let defaultVolume: Double   = 0.8

    // MARK: On/Off

    static func isEnabled(_ mode: StopAlertMode) -> Bool {
        guard UserDefaults.standard.object(forKey: mode.storageKey) != nil else {
            return mode.defaultEnabled
        }
        return UserDefaults.standard.bool(forKey: mode.storageKey)
    }

    // MARK: Sound

    static var soundID: String {
        get { UserDefaults.standard.string(forKey: soundIDKey) ?? AlertSoundCatalog.defaultID }
        set { UserDefaults.standard.set(newValue, forKey: soundIDKey) }
    }

    static var soundFollowsSystem: Bool {
        get {
            guard UserDefaults.standard.object(forKey: followsSystemKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: followsSystemKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: followsSystemKey) }
    }

    static var soundVolume: Double {
        get {
            let v = UserDefaults.standard.double(forKey: volumeKey)
            return v > 0 ? v : defaultVolume
        }
        set { UserDefaults.standard.set(newValue, forKey: volumeKey) }
    }

    // MARK: Vibration

    static var vibrationStyle: AlertVibrationStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: vibStyleKey) ?? AlertVibrationStyle.heavy.rawValue
            return AlertVibrationStyle(rawValue: raw) ?? .heavy
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: vibStyleKey) }
    }

    // MARK: Register defaults

    static func registerDefaults() {
        var defaults: [String: Any] = [:]
        for mode in StopAlertMode.allCases {
            defaults[mode.storageKey] = mode.defaultEnabled
        }
        defaults[soundIDKey]            = AlertSoundCatalog.defaultID
        defaults[followsSystemKey]      = true
        defaults[volumeKey]             = defaultVolume
        defaults[vibStyleKey]           = AlertVibrationStyle.heavy.rawValue
        for slot in DistanceAlertSlot.all {
            defaults[slot.enabledKey] = true
            defaults[slot.metersKey]  = DistanceAlertSlot.defaultMeters[slot.index]
        }
        UserDefaults.standard.register(defaults: defaults)
    }
}

// MARK: - Distance Alert Slots

struct DistanceAlertSlot: Identifiable {
    let index: Int
    var id: Int { index }

    static let count = 3
    static let defaultMeters = [1000, 400, 100]
    static let all = (0..<count).map { DistanceAlertSlot(index: $0) }

    var enabledKey: String { "osmBus_dist_alert_\(index)_enabled" }
    var metersKey:  String { "osmBus_dist_alert_\(index)_meters" }

    var isEnabled: Bool {
        guard UserDefaults.standard.object(forKey: enabledKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    var meters: Int {
        let v = UserDefaults.standard.integer(forKey: metersKey)
        return v > 0 ? v : Self.defaultMeters[index]
    }
}
