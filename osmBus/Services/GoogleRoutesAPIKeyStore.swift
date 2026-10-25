import Foundation

/// Google Routes / Maps API キーを Keychain に保存する。
enum GoogleRoutesAPIKeyStore {
    private static let keychainKey = "google.apiKey.userOverride"
    /// 旧バージョンからの移行専用。新規保存には使用しない。
    private static let legacyUserDefaultsKey = "GoogleRoutesAPIKey.userOverride"
    private static let cacheLock = NSLock()
    private static var cachedUserKey: String?
    private static var hasMemoryCache = false

    /// 設定画面で保存したキー（未設定なら `nil`）。
    static func userConfiguredKey() -> String? {
        cacheLock.lock()
        if hasMemoryCache {
            let cached = cachedUserKey
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let loaded = loadUserConfiguredKeyFromStorage()
        cacheLock.lock()
        cachedUserKey = loaded
        hasMemoryCache = true
        cacheLock.unlock()
        return loaded
    }

    private static func loadUserConfiguredKeyFromStorage() -> String? {
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
        cacheLock.lock()
        hasMemoryCache = true
        cachedUserKey = trimmed.isEmpty ? nil : trimmed
        cacheLock.unlock()

        if trimmed.isEmpty {
            KeychainStore.delete(key: keychainKey)
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        } else {
            KeychainStore.save(key: keychainKey, data: Data(trimmed.utf8))
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        }
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
