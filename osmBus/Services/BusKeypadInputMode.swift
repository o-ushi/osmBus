import Foundation

enum BusKeypadInputMode: String, CaseIterable, Identifiable {
    static let storageKey = "osmBus.busKeypadInputMode"

    /// 判定結果表示後、数字キーでいったんクリアしてから入力する。
    case clearBeforeNewInput
    /// 判定結果表示後も、入力済みの数字の末尾に足していく。
    case appendToExisting

    var id: String { rawValue }

    var settingsTitleKey: String {
        switch self {
        case .clearBeforeNewInput:
            return "テンキー_クリアして新規"
        case .appendToExisting:
            return "テンキー_継ぎ足し"
        }
    }

    static var current: BusKeypadInputMode {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? appendToExisting.rawValue
        return BusKeypadInputMode(rawValue: raw) ?? .appendToExisting
    }
}
