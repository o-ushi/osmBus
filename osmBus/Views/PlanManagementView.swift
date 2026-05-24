import SwiftUI
import UIKit

struct PlanManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PlanStore.self) private var planStore

    var body: some View {
        NavigationStack {
            List {
                currentPlanSection
                planLimitsSection
                restoreSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle(AppLocaleString.text("プラン管理", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocaleString.text("閉じる", locale: locale))
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
                Text(AppLocaleString.text("osmBus_プラン_FREE制限フッター", locale: locale))
            } else {
                Text(AppLocaleString.text("osmBus_プラン_PREMIUM制限フッター", locale: locale))
            }
        }
    }

    private var restoreSection: some View {
        Section {
            Button {
                // StoreKit 連携前のプレースホルダ
            } label: {
                Text(AppLocaleString.text("購入を復元", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)
            .disabled(true)
        } footer: {
            Text(AppLocaleString.text("osmBus_プラン_復元フッター", locale: locale))
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

            Text(AppLocaleString.text("osmBus_プラン切り替え説明", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text(AppLocaleString.text("開発者メニュー", locale: locale))
        }
    }
    #endif

    private func limitLabel(for limit: Int) -> String {
        if limit == Int.max {
            return AppLocaleString.text("無制限", locale: locale)
        }
        return AppLocaleString.formatted("osmBus_件数_%d", locale: locale, limit)
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
        .environment(\.locale, Locale(identifier: "ja"))
}
