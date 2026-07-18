import GoogleMaps
import SwiftUI

struct SettingsNoticeRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GoogleRoutesAPISettingsView: View {
    @Environment(SharedRoutesTrialStore.self) private var trialStore
    @Environment(SharedMapsTrialStore.self) private var mapsTrialStore
    @Environment(\.locale) private var locale

    var body: some View {
        GoogleAPISettingsView(config: GoogleAPISettingsConfigurations.routes, onAfterDelete: {
            mapsTrialStore.refresh()
        }) {
            routesStatusSection
            mapsStatusSection
        }
    }

    @ViewBuilder
    private var routesStatusSection: some View {
        if PlanStore.shared.isPaid && !trialStore.hasUserConfiguredKey {
            // PREMIUM かつ自前キーなし → 両 API の合算説明を1行で表示
            Section {
                SettingsNoticeRow(
                    systemImage: "crown.fill",
                    tint: .yellow,
                    title: AppLocaleString.text("PREMIUM_利用中", locale: locale),
                    text: AppLocaleString.text("PREMIUM_API統合_説明", locale: locale)
                )
            }
        } else if !trialStore.hasUserConfiguredKey && trialStore.isTrialExhausted {
            Section {
                SettingsNoticeRow(
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red,
                    title: AppLocaleString.text("お試し枠_使い切り_タイトル", locale: locale),
                    text: AppLocaleString.text("お試し枠_使い切り_説明", locale: locale)
                )
            }
        } else if !trialStore.hasUserConfiguredKey {
            Section {
                SettingsNoticeRow(
                    systemImage: "key.horizontal.fill",
                    tint: .blue,
                    title: AppLocaleString.formatted(
                        "お試し残り_%d",
                        locale: locale,
                        trialStore.remainingTrialCount
                    ),
                    text: AppLocaleString.text("RoutesAPI_お試し状況_補足", locale: locale)
                )
            }
        }
    }

    @ViewBuilder
    private var mapsStatusSection: some View {
        // PREMIUM 時は routesStatusSection の合算行で済むため非表示
        // 自前キーあり時もトライアル状況は不要
        if !PlanStore.shared.isPaid && !mapsTrialStore.hasUserConfiguredKey {
            Section {
                if mapsTrialStore.isTrialExhausted {
                    SettingsNoticeRow(
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red,
                        title: AppLocaleString.text("Maps_お試し終了_タイトル", locale: locale),
                        text: AppLocaleString.text("Maps_お試し終了_本文", locale: locale)
                    )
                } else {
                    SettingsNoticeRow(
                        systemImage: "map.fill",
                        tint: .blue,
                        title: AppLocaleString.formatted(
                            "Maps_お試し残り_%d",
                            locale: locale,
                            mapsTrialStore.remainingTrialCount
                        ),
                        text: AppLocaleString.text("Maps_お試し説明", locale: locale)
                    )
                }
            } header: {
                Text(AppLocaleString.text("Maps_現在の状態", locale: locale))
            }
        }
    }
}

#Preview("API Settings") {
    NavigationStack {
        GoogleRoutesAPISettingsView()
            .environment(SharedRoutesTrialStore.shared)
            .environment(SharedMapsTrialStore.shared)
            .environment(\.locale, Locale(identifier: "ja"))
    }
}
