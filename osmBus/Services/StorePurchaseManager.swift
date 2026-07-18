import Foundation
import Observation
import StoreKit

enum PurchaseOutcome: Equatable {
    case success
    case cancelled
    case pending
    case failed(String)
}

enum RestoreOutcome: Equatable {
    case restored
    case nothingToRestore
    case failed(String)
}

@MainActor
@Observable
final class StorePurchaseManager {
    static let shared = StorePurchaseManager()

    private(set) var premiumProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var lastErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = listenForTransactionUpdates()
    }

    func start() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: IAPProductID.all)
            premiumProduct = products.first { $0.id == IAPProductID.premium }

            if premiumProduct == nil {
                lastErrorMessage = localized("IAP_商品が見つかりません")
            } else {
                lastErrorMessage = nil
            }
        } catch {
            premiumProduct = nil
            lastErrorMessage = localized("IAP_商品読み込み失敗")
        }
    }

    func purchasePremium() async -> PurchaseOutcome {
        if premiumProduct == nil {
            await loadProducts()
        }

        guard let product = premiumProduct else {
            return .failed(lastErrorMessage ?? localized("IAP_商品が見つかりません"))
        }

        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return .success

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed(localized("IAP_購入失敗"))
            }
        } catch {
            let message = localized("IAP_購入失敗")
            lastErrorMessage = message
            return .failed(message)
        }
    }

    func restorePurchases() async -> RestoreOutcome {
        isRestoring = true
        lastErrorMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()

            if PlanStore.shared.isPaid {
                return .restored
            }
            return .nothingToRestore
        } catch {
            let message = localized("IAP_復元失敗")
            lastErrorMessage = message
            return .failed(message)
        }
    }

    func refreshEntitlements() async {
        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.productID == IAPProductID.premium else { continue }
            guard transaction.revocationDate == nil else { continue }
            hasPremium = true
            break
        }

        PlanStore.shared.applyPremiumEntitlement(hasPremium)
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.unknown
        case .verified(let safe):
            return safe
        }
    }

    private func localized(_ key: String) -> String {
        AppLocaleString.text(key, locale: Locale.current)
    }
}
