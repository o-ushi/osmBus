import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case english = "en"
    case japanese = "ja"
    case vietnamese = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        case .vietnamese: return "Tiếng Việt"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .vietnamese: return "🇻🇳"
        }
    }

    var fullLabel: String {
        "\(flag) \(displayName)"
    }

    static func resolved(from locale: Locale) -> AppLanguage {
        let code =
            locale.language.languageCode?.identifier.lowercased()
            ?? locale.identifier.split(separator: "-").first.map(String.init)?.lowercased()
            ?? ""
        if code.hasPrefix("en") { return .english }
        if code.hasPrefix("vi") { return .vietnamese }
        if code.hasPrefix("ja") { return .japanese }
        return .english
    }
}
