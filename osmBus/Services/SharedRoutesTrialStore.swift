import Foundation
import Observation

// MARK: - Shared monthly trial counter

/// Routes / Maps トライアルストア共通の月次カウンターロジック。
enum MonthlyTrialCounter {
    static let freeMaxTrials = 30
    static let premiumMaxTrials = 60

    nonisolated private static var currentYearMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    nonisolated static func resetIfNewMonthStored(usedCountKey: String, lastResetMonthKey: String) {
        let current = currentYearMonth
        let last = UserDefaults.standard.string(forKey: lastResetMonthKey) ?? ""
        guard current != last else { return }
        UserDefaults.standard.set(0, forKey: usedCountKey)
        UserDefaults.standard.set(current, forKey: lastResetMonthKey)
    }

    nonisolated static func remainingCountStored(usedCountKey: String, lastResetMonthKey: String) -> Int {
        resetIfNewMonthStored(usedCountKey: usedCountKey, lastResetMonthKey: lastResetMonthKey)
        let isPaid = UserDefaults.standard.string(forKey: "osmBus.plan") == "paid"
        let maxTrials = isPaid ? premiumMaxTrials : freeMaxTrials
        return max(0, maxTrials - UserDefaults.standard.integer(forKey: usedCountKey))
    }

    nonisolated static func storedUsedCount(for usedCountKey: String) -> Int {
        UserDefaults.standard.integer(forKey: usedCountKey)
    }

    static func resetIfNewMonth(
        usedCount: inout Int,
        usedCountKey: String,
        lastResetMonthKey: String,
        sessionConsumedSignatures: inout Set<String>
    ) {
        let current = Self.currentYearMonth
        let last = UserDefaults.standard.string(forKey: lastResetMonthKey) ?? ""
        guard current != last else { return }
        usedCount = 0
        UserDefaults.standard.set(0, forKey: usedCountKey)
        UserDefaults.standard.set(current, forKey: lastResetMonthKey)
        sessionConsumedSignatures.removeAll()
    }
}

@MainActor
@Observable
final class SharedRoutesTrialStore {
    static let shared = SharedRoutesTrialStore()

    nonisolated static let freeMaxTrials = MonthlyTrialCounter.freeMaxTrials
    nonisolated static let premiumMaxTrials = MonthlyTrialCounter.premiumMaxTrials
    nonisolated private static let usedCountKey = "osmBus.sharedRoutesTrialUsedCount"
    nonisolated private static let lastResetMonthKey = "osmBus.sharedRoutesTrialLastResetMonth"

    private(set) var usedCount: Int
    private var sessionConsumedSignatures: Set<String> = []

    private init() {
        Self.resetIfNewMonthStored()
        usedCount = UserDefaults.standard.integer(forKey: Self.usedCountKey)
    }

    nonisolated private static func resetIfNewMonthStored() {
        MonthlyTrialCounter.resetIfNewMonthStored(
            usedCountKey: usedCountKey,
            lastResetMonthKey: lastResetMonthKey
        )
    }

    nonisolated static func remainingTrialCountStored() -> Int {
        MonthlyTrialCounter.remainingCountStored(
            usedCountKey: usedCountKey,
            lastResetMonthKey: lastResetMonthKey
        )
    }

    nonisolated static func canUseSharedKeyStored() -> Bool {
        GoogleRoutesAPIKeyStore.userConfiguredKey() == nil
            && !Secrets.sharedGoogleRoutesAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remainingTrialCountStored() > 0
    }

    private func resetIfNewMonth() {
        MonthlyTrialCounter.resetIfNewMonth(
            usedCount: &usedCount,
            usedCountKey: Self.usedCountKey,
            lastResetMonthKey: Self.lastResetMonthKey,
            sessionConsumedSignatures: &sessionConsumedSignatures
        )
    }

    private var maxTrials: Int {
        PlanStore.shared.isPaid ? Self.premiumMaxTrials : Self.freeMaxTrials
    }

    var remainingTrialCount: Int {
        return max(0, maxTrials - usedCount)
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
        !hasUserConfiguredKey && Self.canUseSharedKeyStored()
    }

    func consumeTrialIfNeeded(signature: String) -> Bool {
        resetIfNewMonth()
        guard !hasUserConfiguredKey else { return true }
        if sessionConsumedSignatures.contains(signature) { return true }
        guard remainingTrialCount > 0 else { return false }
        usedCount = min(usedCount + 1, maxTrials)
        UserDefaults.standard.set(usedCount, forKey: Self.usedCountKey)
        sessionConsumedSignatures.insert(signature)
        return true
    }

    func hasSessionSignature(_ signature: String) -> Bool {
        sessionConsumedSignatures.contains(signature)
    }

    func refresh() {
        resetIfNewMonth()
        usedCount = UserDefaults.standard.integer(forKey: Self.usedCountKey)
    }
}

// MARK: - Maps SDK trial store

@MainActor
@Observable
final class SharedMapsTrialStore {
    static let shared = SharedMapsTrialStore()

    nonisolated static let freeMaxTrials = MonthlyTrialCounter.freeMaxTrials
    nonisolated static let premiumMaxTrials = MonthlyTrialCounter.premiumMaxTrials
    nonisolated private static let usedCountKey = "osmBus.sharedMapsTrialUsedCount"
    nonisolated private static let lastResetMonthKey = "osmBus.sharedMapsTrialLastResetMonth"

    private(set) var usedCount: Int
    private var sessionConsumedSignatures: Set<String> = []

    private init() {
        Self.resetIfNewMonthStored()
        usedCount = UserDefaults.standard.integer(forKey: Self.usedCountKey)
    }

    nonisolated private static func resetIfNewMonthStored() {
        MonthlyTrialCounter.resetIfNewMonthStored(
            usedCountKey: usedCountKey,
            lastResetMonthKey: lastResetMonthKey
        )
    }

    nonisolated static func remainingTrialCountStored() -> Int {
        MonthlyTrialCounter.remainingCountStored(
            usedCountKey: usedCountKey,
            lastResetMonthKey: lastResetMonthKey
        )
    }

    nonisolated static func canUseSharedKeyStored() -> Bool {
        GoogleRoutesAPIKeyStore.userConfiguredKey() == nil
            && !Secrets.googleMapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remainingTrialCountStored() > 0
    }

    private func resetIfNewMonth() {
        MonthlyTrialCounter.resetIfNewMonth(
            usedCount: &usedCount,
            usedCountKey: Self.usedCountKey,
            lastResetMonthKey: Self.lastResetMonthKey,
            sessionConsumedSignatures: &sessionConsumedSignatures
        )
    }

    private var maxTrials: Int {
        PlanStore.shared.isPaid ? Self.premiumMaxTrials : Self.freeMaxTrials
    }

    var remainingTrialCount: Int {
        return max(0, maxTrials - usedCount)
    }

    var isTrialExhausted: Bool {
        remainingTrialCount <= 0
    }

    var hasUserConfiguredKey: Bool {
        GoogleRoutesAPIKeyStore.userConfiguredKey() != nil
    }

    var canShowMap: Bool {
        GoogleRoutesAPIKeyStore.userConfiguredKey() != nil || Self.canUseSharedKeyStored()
    }

    func consumeTrialIfNeeded(signature: String) {
        resetIfNewMonth()
        guard GoogleRoutesAPIKeyStore.userConfiguredKey() == nil else { return }
        guard !sessionConsumedSignatures.contains(signature) else { return }
        guard remainingTrialCount > 0 else { return }
        usedCount = min(usedCount + 1, maxTrials)
        UserDefaults.standard.set(usedCount, forKey: Self.usedCountKey)
        sessionConsumedSignatures.insert(signature)
    }

    func refresh() {
        resetIfNewMonth()
        usedCount = UserDefaults.standard.integer(forKey: Self.usedCountKey)
    }
}
