import Foundation

/// Google Routes API キーを UserDefaults に保存する。
enum GoogleRoutesAPIKeyStore {
    static let userDefaultsKey = "GoogleRoutesAPIKey.userOverride"

    /// 設定画面で保存したキー（未設定なら `nil`）。
    static func userConfiguredKey() -> String? {
        guard let value = UserDefaults.standard.string(forKey: userDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    /// 空でない文字列を渡すと保存する。空にすると削除する。
    static func setUserConfiguredKey(_ raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: userDefaultsKey)
        }
    }

    /// ルート検索などで使うキー（ユーザー設定キー → お試し共有キーの順）。
    static func effectiveAPIKey() -> String? {
        if let userKey = userConfiguredKey() {
            return userKey
        }
        guard SharedRoutesTrialStore.canUseSharedKeyStored() else { return nil }
        let sharedKey = Secrets.sharedGoogleRoutesAPIKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sharedKey.isEmpty ? nil : sharedKey
    }

    static var isConfigured: Bool {
        userConfiguredKey() != nil || SharedRoutesTrialStore.canUseSharedKeyStored()
    }

    static var hasUserConfiguredKey: Bool {
        userConfiguredKey() != nil
    }
}
