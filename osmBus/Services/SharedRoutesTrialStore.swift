import Foundation
import Observation

@MainActor
@Observable
final class SharedRoutesTrialStore {
    static let shared = SharedRoutesTrialStore()

    static let maxTrials = 10
    private static let usedCountKey = "osmBus.sharedRoutesTrialUsedCount"

    private(set) var usedCount: Int
    private var sessionConsumedSignatures: Set<String> = []

    private init() {
        usedCount = UserDefaults.standard.integer(forKey: Self.usedCountKey)
    }

    nonisolated static func remainingTrialCountStored() -> Int {
        max(0, maxTrials - UserDefaults.standard.integer(forKey: usedCountKey))
    }

    nonisolated static func canUseSharedKeyStored() -> Bool {
        GoogleRoutesAPIKeyStore.userConfiguredKey() == nil
            && !Secrets.sharedGoogleRoutesAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remainingTrialCountStored() > 0
    }

    var remainingTrialCount: Int {
        max(0, Self.maxTrials - usedCount)
    }

    var isTrialExhausted: Bool {
        remainingTrialCount <= 0
    }

    var hasUserConfiguredKey: Bool {
        GoogleRoutesAPIKeyStore.userConfiguredKey() != nil
    }

    var canUseSharedKey: Bool {
        Self.canUseSharedKeyStored()
    }

    var isUsingSharedTrialKey: Bool {
        hasUserConfiguredKey == false && canUseSharedKey
    }

    func consumeTrialIfNeeded(signature: String) -> Bool {
        guard !hasUserConfiguredKey else { return true }

        if sessionConsumedSignatures.contains(signature) {
            return true
        }

        guard remainingTrialCount > 0 else { return false }

        usedCount = min(usedCount + 1, Self.maxTrials)
        UserDefaults.standard.set(usedCount, forKey: Self.usedCountKey)
        sessionConsumedSignatures.insert(signature)
        return true
    }

    func hasSessionSignature(_ signature: String) -> Bool {
        sessionConsumedSignatures.contains(signature)
    }

    func refresh() {
        usedCount = UserDefaults.standard.integer(forKey: Self.usedCountKey)
    }
}
