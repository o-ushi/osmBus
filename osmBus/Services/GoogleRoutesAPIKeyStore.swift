import Foundation

/// Google Routes / Maps API キーを Keychain に保存する。
enum GoogleRoutesAPIKeyStore {
    private static let keychainKey = "google.apiKey.userOverride"
    /// 旧バージョンからの移行専用。新規保存には使用しない。
    private static let legacyUserDefaultsKey = "GoogleRoutesAPIKey.userOverride"

    /// 設定画面で保存したキー（未設定なら `nil`）。
    static func userConfiguredKey() -> String? {
        if let data = KeychainStore.load(key: keychainKey),
           let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        guard let legacy = UserDefaults.standard.string(forKey: legacyUserDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !legacy.isEmpty else {
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
            return nil
        }
        KeychainStore.save(key: keychainKey, data: Data(legacy.utf8))
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        return legacy
    }

    /// 空でない文字列を渡すと保存する。空にすると削除する。
    static func setUserConfiguredKey(_ raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            KeychainStore.delete(key: keychainKey)
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        } else {
            KeychainStore.save(key: keychainKey, data: Data(trimmed.utf8))
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        }
    }

    /// ルート検索などで使うキー（ユーザー設定キー → PREMIUM共有キー → お試し共有キーの順）。
    static func effectiveAPIKey() -> String? {
        if let userKey = userConfiguredKey() { return userKey }
        guard isPremiumStored || SharedRoutesTrialStore.canUseSharedKeyStored() else { return nil }
        let sharedKey = Secrets.sharedGoogleRoutesAPIKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sharedKey.isEmpty ? nil : sharedKey
    }

    static var isConfigured: Bool {
        userConfiguredKey() != nil || isPremiumStored || SharedRoutesTrialStore.canUseSharedKeyStored()
    }

    private static var isPremiumStored: Bool {
        UserDefaults.standard.string(forKey: "osmBus.plan") == AppPlan.paid.rawValue
    }

    static var hasUserConfiguredKey: Bool {
        userConfiguredKey() != nil
    }
}

// MARK: - Google Maps API key store (Routes API・Maps SDK で同一キーを使うため委譲)

enum GoogleMapsAPIKeyStore {
    static func userConfiguredKey() -> String? { GoogleRoutesAPIKeyStore.userConfiguredKey() }
    static func setUserConfiguredKey(_ raw: String?) { GoogleRoutesAPIKeyStore.setUserConfiguredKey(raw) }
    static var hasUserConfiguredKey: Bool { GoogleRoutesAPIKeyStore.hasUserConfiguredKey }
}
