import SwiftUI
import UIKit

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PlanStore.self) private var planStore

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return AppLocaleString.formatted("osmBus_バージョン", locale: locale, version, build)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .center, spacing: 18) {
                        helpHeaderAppIconView
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("osmBus")
                                .font(.title.weight(.bold))
                            Text(appVersion)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Text(AppLocaleString.text("osmBus_ヘルプ紹介文", locale: locale))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .listRowBackground(Color.clear)
                }

                Section(AppLocaleString.text("基本操作", locale: locale)) {
                    helpRow(
                        icon: "mappin.and.ellipse",
                        color: .blue,
                        titleKey: "osmBus_help_場所を登録_title",
                        bodyKey: "osmBus_help_場所を登録_body"
                    )
                    helpRow(
                        icon: "mappin.circle.fill",
                        color: .teal,
                        titleKey: "osmBus_help_目的地_title",
                        bodyKey: "osmBus_help_目的地_body"
                    )
                    helpRow(
                        icon: "location.fill",
                        color: .green,
                        titleKey: "osmBus_help_現在地_title",
                        bodyKey: "osmBus_help_現在地_body"
                    )
                    helpRow(
                        icon: "number",
                        color: .orange,
                        titleKey: "osmBus_help_バス番号_title",
                        bodyKey: "osmBus_help_バス番号_body"
                    )
                }

                Section(AppLocaleString.text("API キー", locale: locale)) {
                    helpRow(
                        icon: "key.fill",
                        color: .pink,
                        titleKey: "osmBus_help_APIキー_とは_title",
                        bodyKey: "osmBus_help_APIキー_とは_body"
                    )
                    helpRow(
                        icon: "gearshape.fill",
                        color: .blue,
                        titleKey: "osmBus_help_APIキー_設定_title",
                        bodyKey: "osmBus_help_APIキー_設定_body"
                    )
                    helpRow(
                        icon: "lock.shield.fill",
                        color: .teal,
                        titleKey: "osmBus_help_APIキー_安心_title",
                        bodyKey: "osmBus_help_APIキー_安心_body"
                    )
                }

                Section(AppLocaleString.text("結果の見方", locale: locale)) {
                    helpRow(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        titleKey: "osmBus_help_乗車_title",
                        bodyKey: "osmBus_help_乗車_body"
                    )
                    helpRow(
                        icon: "xmark.circle.fill",
                        color: .red,
                        titleKey: "osmBus_help_不可_title",
                        bodyKey: "osmBus_help_不可_body"
                    )
                }

                Section(AppLocaleString.text("トラブルシュート", locale: locale)) {
                    helpRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        titleKey: "osmBus_help_ルートなし_title",
                        bodyKey: "osmBus_help_ルートなし_body"
                    )
                    helpRow(
                        icon: "wifi.slash",
                        color: .gray,
                        titleKey: "osmBus_help_通信_title",
                        bodyKey: "osmBus_help_通信_body"
                    )
                }

                Section(AppLocaleString.text("プラン", locale: locale)) {
                    helpRow(
                        icon: "crown.fill",
                        color: .orange,
                        titleKey: "osmBus_help_プラン_title",
                        bodyKey: "osmBus_help_プラン_body"
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(AppLocaleString.text("ヘルプ", locale: locale))
            .navigationBarTitleDisplayMode(.large)
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

    /// `PlanManagementView` のプラン別アプリアイコンと同じ解決順。
    @ViewBuilder
    private var helpHeaderAppIconView: some View {
        let imageName = planStore.isFree ? "ImageFree" : "ImagePremium"
        if let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image("ImagePremium")
                .resizable()
                .scaledToFit()
        }
    }

    private func helpRow(icon: String, color: Color, titleKey: String, bodyKey: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocaleString.text(titleKey, locale: locale))
                    .font(.subheadline.weight(.semibold))
                Text(AppLocaleString.text(bodyKey, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HelpView()
        .environment(PlanStore.shared)
        .environment(\.locale, Locale(identifier: "ja"))
}
