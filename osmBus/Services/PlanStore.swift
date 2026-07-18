import Foundation
import Observation

enum AppPlan: String, CaseIterable {
    case free
    case paid

    var localizationKey: String {
        switch self {
        case .free: "FREE"
        case .paid: "PREMIUM"
        }
    }
}

@Observable
final class PlanStore {
    static let shared = PlanStore()

    static let freeItemLimit = 3
    private static let storageKey = "osmBus.plan"

    private(set) var currentPlan: AppPlan {
        didSet {
            guard oldValue != currentPlan else { return }
            save()
            enforceLimitsForCurrentPlan()
        }
    }

    var isPaid: Bool { currentPlan == .paid }
    var isFree: Bool { currentPlan == .free }

    var savedPlaceLimit: Int {
        isPaid ? Int.max : Self.freeItemLimit
    }

    var historyLimit: Int {
        isPaid ? Int.max : Self.freeItemLimit
    }

    var canAddSavedPlace: Bool {
        SavedPlaceStore.loadAll().count < savedPlaceLimit
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let plan = AppPlan(rawValue: raw) {
            currentPlan = plan
        } else {
            currentPlan = .free
        }
        enforceLimitsForCurrentPlan()
    }

    func setPlan(_ plan: AppPlan) {
        currentPlan = plan
    }

    /// StoreKit のエンタイトルメントに基づいてプランを更新する。
    func applyPremiumEntitlement(_ hasPremium: Bool) {
        setPlan(hasPremium ? .paid : .free)
    }

    func enforceLimitsForCurrentPlan() {
        DestinationHistoryStore.trim(to: historyLimit)
        SavedPlaceStore.trim(to: savedPlaceLimit)
    }

    private func save() {
        UserDefaults.standard.set(currentPlan.rawValue, forKey: Self.storageKey)
    }
}
