import Foundation

/// アプリの表示言語に対応した文字列解決。
/// モーダルやシートでは `environment(\.locale)` がシステム言語（端末の日本語など）に上書きされることがあるため、
/// **設定で選んだ言語**（`AppLanguage.storageKey`）を `Locale` より優先して `.lproj` を選ぶ。
enum AppLocaleString {
    /// `localizedString(forKey:value:)` がキー欠落時だけ返す値（通常の文言に含まれない私有領域文字）。
    private static let missingKeySentinel = "\u{F8FF}"

    static func text(_ key: String, locale: Locale) -> String {
        for bundle in bundles(preferredEnvironmentLocale: locale) {
            let value = bundle.localizedString(forKey: key, value: missingKeySentinel, table: nil)
            if value != missingKeySentinel {
                return value
            }
        }
        return key
    }

    /// ViewModel / Service など `@Environment(\.locale)` が使えない場所向け。
    static func currentText(_ key: String) -> String {
        let code = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.english.rawValue
        return text(key, locale: Locale(identifier: code))
    }

    static func formatted(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let format = text(key, locale: locale)
        return withVaList(arguments) { pointer in
            NSString(format: format, locale: locale, arguments: pointer) as String
        }
    }

    static func currentFormatted(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(key, locale: currentLocale, arguments)
    }

    static var currentLocale: Locale {
        let code = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.english.rawValue
        return Locale(identifier: code)
    }

    /// `UserDefaults` の言語があれば最優先。無ければ環境の `locale` から推測。
    private static func preferredAppLanguage(environmentLocale: Locale) -> AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: AppLanguage.storageKey),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        return AppLanguage.resolved(from: environmentLocale)
    }

    /// `AppLanguage` の rawValue（en / ja / vi）と `.lproj` を 1:1 で対応させ、欠落キーは他言語へフォールバックする。
    private static func bundles(preferredEnvironmentLocale: Locale) -> [Bundle] {
        let primary = preferredAppLanguage(environmentLocale: preferredEnvironmentLocale)
        let order: [AppLanguage] = {
            switch primary {
            case .english:
                return [.english, .japanese, .vietnamese]
            case .japanese:
                return [.japanese, .english, .vietnamese]
            case .vietnamese:
                return [.vietnamese, .english, .japanese]
            }
        }()
        var seen: Set<String> = []
        var result: [Bundle] = []
        for lang in order {
            guard let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { continue }
            if seen.insert(bundle.bundlePath).inserted {
                result.append(bundle)
            }
        }
        return result
    }
}
