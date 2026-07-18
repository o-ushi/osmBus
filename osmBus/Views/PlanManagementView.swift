import SwiftUI
import UIKit

struct PlanManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PlanStore.self) private var planStore
    @Environment(StorePurchaseManager.self) private var store

    @State private var purchaseAlert: PurchaseAlert?

    private enum PurchaseAlert: Identifiable {
        case success
        case restoreSuccess
        case restoreEmpty
        case pending
        case failure(String)

        var id: String {
            switch self {
            case .success: "success"
            case .restoreSuccess: "restoreSuccess"
            case .restoreEmpty: "restoreEmpty"
            case .pending: "pending"
            case .failure(let message): "failure-\(message)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                currentPlanSection
                planLimitsSection
                if planStore.isFree {
                    upgradeSection
                }
                restoreSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle(AppLocaleString.text("プラン管理", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if store.premiumProduct == nil && !store.isLoadingProducts {
                    await store.loadProducts()
                }
            }
            .alert(item: $purchaseAlert) { alert in
                switch alert {
                case .success:
                    Alert(
                        title: Text(AppLocaleString.text("PREMIUM", locale: locale)),
                        message: Text(AppLocaleString.text("プレミアムプランへのアップグレードが完了しました！", locale: locale)),
                        dismissButton: .default(Text(AppLocaleString.text("OK", locale: locale)))
                    )
                case .restoreSuccess:
                    Alert(
                        title: Text(AppLocaleString.text("購入を復元", locale: locale)),
                        message: Text(AppLocaleString.text("購入を復元しました。", locale: locale)),
                        dismissButton: .default(Text(AppLocaleString.text("OK", locale: locale)))
                    )
                case .restoreEmpty:
                    Alert(
                        title: Text(AppLocaleString.text("購入を復元", locale: locale)),
                        message: Text(AppLocaleString.text("復元できる購入が見つかりませんでした。", locale: locale)),
                        dismissButton: .default(Text(AppLocaleString.text("OK", locale: locale)))
                    )
                case .pending:
                    Alert(
                        title: Text(AppLocaleString.text("PREMIUMにアップグレード", locale: locale)),
                        message: Text(AppLocaleString.text("IAP_購入保留", locale: locale)),
                        dismissButton: .default(Text(AppLocaleString.text("OK", locale: locale)))
                    )
                case .failure(let message):
                    Alert(
                        title: Text(AppLocaleString.text("PREMIUMにアップグレード", locale: locale)),
                        message: Text(message),
                        dismissButton: .default(Text(AppLocaleString.text("OK", locale: locale)))
                    )
                }
            }
        }
        .environment(\.locale, locale)
    }

    private var currentPlanSection: some View {
        Section {
            HStack(spacing: 16) {
                planIconView
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocaleString.text("現在のプラン", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppLocaleString.text(planStore.currentPlan.localizationKey, locale: locale))
                        .font(.title2.bold())
                        .foregroundStyle(planStore.isFree ? .primary : Color.orange)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        } footer: {
            if planStore.isFree {
                Text(AppLocaleString.text("プラン_FREE説明", locale: locale))
            }
        }
    }

    private var planLimitsSection: some View {
        Section {
            HStack {
                Label(AppLocaleString.text("履歴", locale: locale), systemImage: "clock.arrow.circlepath")
                Spacer()
                Text(limitLabel(for: planStore.historyLimit))
                    .foregroundStyle(planStore.isFree ? .orange : .secondary)
                    .fontWeight(planStore.isFree ? .semibold : .regular)
            }

            HStack {
                Label(AppLocaleString.text("登録済みの場所", locale: locale), systemImage: "mappin.and.ellipse")
                Spacer()
                Text(limitLabel(for: planStore.savedPlaceLimit))
                    .foregroundStyle(planStore.isFree ? .orange : .secondary)
                    .fontWeight(planStore.isFree ? .semibold : .regular)
            }
        } footer: {
            if planStore.isFree {
                Text(AppLocaleString.formatted("プラン_FREE制限フッター", locale: locale, PlanStore.freeItemLimit))
            } else {
                Text(AppLocaleString.text("プラン_PREMIUM制限フッター", locale: locale))
            }
        }
    }

    private var upgradeSection: some View {
        Section {
            Button {
                Task { await purchasePremium() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLocaleString.text("PREMIUMにアップグレード", locale: locale))
                            .font(.body.weight(.semibold))
                        Text(upgradeSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if store.isPurchasing || store.isLoadingProducts {
                        ProgressView()
                    }
                }
            }
            .disabled(store.isPurchasing || store.isLoadingProducts || store.premiumProduct == nil)

            if store.premiumProduct == nil && !store.isLoadingProducts {
                Button {
                    Task { await store.loadProducts() }
                } label: {
                    Label(AppLocaleString.text("IAP_再読み込み", locale: locale), systemImage: "arrow.clockwise")
                }
            }

            if let errorMessage = store.lastErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } footer: {
            Text(AppLocaleString.text("プラン_FREE制限フッター", locale: locale))
        }
    }

    private var restoreSection: some View {
        Section {
            Button {
                Task { await restorePurchases() }
            } label: {
                HStack {
                    Text(AppLocaleString.text("購入を復元", locale: locale))
                        .frame(maxWidth: .infinity)
                    if store.isRestoring {
                        ProgressView()
                    }
                }
            }
            .disabled(store.isRestoring || store.isPurchasing)
        } footer: {
            Text(AppLocaleString.text("プラン_復元フッター", locale: locale))
                .font(.footnote)
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            Picker(AppLocaleString.text("テスト用プラン", locale: locale), selection: Binding(
                get: { planStore.currentPlan },
                set: { planStore.setPlan($0) }
            )) {
                Text(AppLocaleString.text("FREE", locale: locale)).tag(AppPlan.free)
                Text(AppLocaleString.text("PREMIUM", locale: locale)).tag(AppPlan.paid)
            }
            .pickerStyle(.segmented)

            Text(AppLocaleString.text("プラン切り替え説明", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text(AppLocaleString.text("開発者メニュー", locale: locale))
        }
    }
    #endif

    private var upgradeSubtitle: String {
        if store.isLoadingProducts {
            return AppLocaleString.text("取得中…", locale: locale)
        }
        if let product = store.premiumProduct {
            return product.displayPrice
        }
        return AppLocaleString.text("IAP_商品読み込み中", locale: locale)
    }

    private func limitLabel(for limit: Int) -> String {
        if limit == Int.max {
            return AppLocaleString.text("無制限", locale: locale)
        }
        return AppLocaleString.formatted("件数_%d", locale: locale, limit)
    }

    private func purchasePremium() async {
        let outcome = await store.purchasePremium()
        switch outcome {
        case .success:
            purchaseAlert = .success
        case .cancelled:
            break
        case .pending:
            purchaseAlert = .pending
        case .failed(let message):
            purchaseAlert = .failure(message)
        }
    }

    private func restorePurchases() async {
        let outcome = await store.restorePurchases()
        switch outcome {
        case .restored:
            purchaseAlert = .restoreSuccess
        case .nothingToRestore:
            purchaseAlert = .restoreEmpty
        case .failed(let message):
            purchaseAlert = .failure(message)
        }
    }

    private var planIconView: some View {
        Group {
            let imageName = planStore.isFree ? "ImageFree" : "ImagePremium"
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            LinearGradient(
                                colors: planStore.isFree
                                    ? [.gray, .gray.opacity(0.7)]
                                    : [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: planStore.isFree ? "bus.fill" : "crown.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    PlanManagementView()
        .environment(PlanStore.shared)
        .environment(StorePurchaseManager.shared)
        .environment(\.locale, Locale(identifier: "ja"))
}
