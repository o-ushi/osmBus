import SwiftUI

private enum AppSettingsRoute: Hashable {
    case apiSettings
    case alertSettings
    case privacyData
}

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @AppStorage(AppLanguage.storageKey) private var appLanguageCode = AppLanguage.english.rawValue
    @AppStorage(BusKeypadInputMode.storageKey) private var busKeypadInputModeRaw =
        BusKeypadInputMode.appendToExisting.rawValue
    @AppStorage(BusNumberTableSortMode.storageKey) private var busNumberTableSortModeRaw =
        BusNumberTableSortMode.byDirection.rawValue
    @AppStorage(BusNumberTableDistanceMetric.storageKey) private var busNumberTableDistanceMetricRaw =
        BusNumberTableDistanceMetric.walkPriority.rawValue
    @AppStorage(KeypadHapticManager.hapticEnabledKey)   private var hapticEnabled   = true
    @AppStorage(KeypadHapticManager.hapticIntensityKey) private var hapticIntensityRaw = "medium"
    @AppStorage(KeypadHapticManager.soundEnabledKey)    private var soundEnabled    = false
    @AppStorage(KeypadHapticManager.soundVolumeKey)     private var soundVolume     = 0.5
    @State private var path = NavigationPath()
    @EnvironmentObject private var locationService: LocationService
    @ObservedObject private var catalogDownloader = BusRouteCatalogDownloader.shared
    @State private var catalogSummary = BusRouteCatalogStore.summary()
    @State private var catalogNote: String?

    var opensAPISettingsOnAppear = false

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageCode) ?? .english
    }

    private var currentBusKeypadInputMode: BusKeypadInputMode {
        BusKeypadInputMode(rawValue: busKeypadInputModeRaw) ?? .appendToExisting
    }

    private var currentBusNumberTableSortMode: BusNumberTableSortMode {
        BusNumberTableSortMode(rawValue: busNumberTableSortModeRaw) ?? .byDirection
    }

    private var currentBusNumberTableDistanceMetric: BusNumberTableDistanceMetric {
        BusNumberTableDistanceMetric(rawValue: busNumberTableDistanceMetricRaw) ?? .walkPriority
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            appLanguageCode = language.rawValue
                        } label: {
                            HStack {
                                Text(language.fullLabel)
                                    .foregroundStyle(.primary)
                                    .fontWeight(currentLanguage == language ? .semibold : .regular)
                                Spacer()
                                if currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(AppLocaleString.text("言語", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("アプリの表示言語を変更できます。", locale: locale))
                }

                Section {
                    NavigationLink(value: AppSettingsRoute.alertSettings) {
                        Label(
                            AppLocaleString.text("設定_到着アラート", locale: locale),
                            systemImage: "bell.badge"
                        )
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text(AppLocaleString.text("設定_到着アラート", locale: locale))
                }

                Section {
                    ForEach(BusKeypadInputMode.allCases) { mode in
                        Button {
                            busKeypadInputModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Text(AppLocaleString.text(mode.settingsTitleKey, locale: locale))
                                    .foregroundStyle(.primary)
                                    .fontWeight(currentBusKeypadInputMode == mode ? .semibold : .regular)
                                Spacer()
                                if currentBusKeypadInputMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(AppLocaleString.text("テンキー入力", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("テンキー入力_フッター", locale: locale))
                }

                Section {
                    ForEach(BusNumberTableSortMode.allCases) { mode in
                        Button {
                            busNumberTableSortModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Text(AppLocaleString.text(mode.settingsTitleKey, locale: locale))
                                    .foregroundStyle(.primary)
                                    .fontWeight(currentBusNumberTableSortMode == mode ? .semibold : .regular)
                                Spacer()
                                if currentBusNumberTableSortMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(AppLocaleString.text("バス番号表の並び順", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("バス番号表の並び順_フッター", locale: locale))
                }

                if currentBusNumberTableSortMode == .byDistance {
                    Section {
                        ForEach(BusNumberTableDistanceMetric.allCases) { metric in
                            Button {
                                busNumberTableDistanceMetricRaw = metric.rawValue
                            } label: {
                                HStack {
                                    Text(AppLocaleString.text(metric.settingsTitleKey, locale: locale))
                                        .foregroundStyle(.primary)
                                        .fontWeight(currentBusNumberTableDistanceMetric == metric ? .semibold : .regular)
                                    Spacer()
                                    if currentBusNumberTableDistanceMetric == metric {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text(AppLocaleString.text("距離基準_測り方_フッター", locale: locale))
                    }
                }

                Section {
                    if UIDevice.current.userInterfaceIdiom != .pad {
                        Toggle(
                            AppLocaleString.text("キーフィードバック_バイブ", locale: locale),
                            isOn: $hapticEnabled
                        )
                        .onChange(of: hapticEnabled) { _, on in
                            if on { KeypadHapticManager.shared.previewHaptic(.medium) }
                        }

                        if hapticEnabled {
                            Picker(
                                AppLocaleString.text("キーフィードバック_バイブ強さ", locale: locale),
                                selection: $hapticIntensityRaw
                            ) {
                                ForEach(KeypadHapticIntensity.allCases) { intensity in
                                    Text(AppLocaleString.text(intensity.titleKey, locale: locale))
                                        .tag(intensity.rawValue)
                                }
                            }
                            .onChange(of: hapticIntensityRaw) { _, raw in
                                let intensity = KeypadHapticIntensity(rawValue: raw) ?? .medium
                                KeypadHapticManager.shared.previewHaptic(intensity)
                            }
                        }
                    }

                    Toggle(
                        AppLocaleString.text("キーフィードバック_クリック", locale: locale),
                        isOn: $soundEnabled
                    )
                    .onChange(of: soundEnabled) { _, on in
                        if on { KeypadHapticManager.shared.previewSound(volume: soundVolume) }
                    }

                    if soundEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(AppLocaleString.text("キーフィードバック_音量", locale: locale))
                                Spacer()
                                Text("\(Int(soundVolume * 100))%")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $soundVolume, in: 0...1, step: 0.05)
                                .onChange(of: soundVolume) { _, vol in
                                    KeypadHapticManager.shared.previewSound(volume: vol)
                                }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(AppLocaleString.text("キーフィードバック", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("キーフィードバック_フッター", locale: locale))
                }

                routeCatalogSection

                Section {
                    NavigationLink(value: AppSettingsRoute.apiSettings) {
                        HStack {
                            Label(AppLocaleString.text("Google API", locale: locale), systemImage: "key.horizontal.fill")
                            Spacer()
                            if GoogleRoutesAPIKeyStore.hasUserConfiguredKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text(AppLocaleString.text("API 連携", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("API連携フッター", locale: locale))
                }

                Section {
                    NavigationLink(value: AppSettingsRoute.privacyData) {
                        Label(
                            AppLocaleString.text("プライバシーとデータ", locale: locale),
                            systemImage: "hand.raised.fill"
                        )
                    }
                } footer: {
                    Text(AppLocaleString.text("プライバシー_設定フッター", locale: locale))
                }
            }
            .navigationTitle(AppLocaleString.text("設定", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AppSettingsRoute.self) { route in
                switch route {
                case .apiSettings:
                    GoogleRoutesAPISettingsView()
                        .environment(SharedRoutesTrialStore.shared)
                        .environment(SharedMapsTrialStore.shared)
                        .environment(\.locale, locale)
                case .alertSettings:
                    StopAlertSettingsView()
                        .environment(\.locale, locale)
                case .privacyData:
                    PrivacyDataView()
                        .environment(\.locale, locale)
                }
            }
            .onAppear {
                catalogSummary = BusRouteCatalogStore.summary()
                guard opensAPISettingsOnAppear, path.isEmpty else { return }
                path.append(AppSettingsRoute.apiSettings)
            }
            .onChange(of: catalogDownloader.activity) { _, _ in
                catalogSummary = BusRouteCatalogStore.summary()
                if case .idle = catalogDownloader.activity { return }
                catalogNote = nil
            }
            .id(locale.identifier)
        }
        .environment(\.locale, locale)
    }

    private var catalogBusy: Bool {
        if case .working = catalogDownloader.activity { return true }
        return false
    }

    private var catalogStatusText: String {
        if let catalogNote { return catalogNote }
        switch catalogDownloader.activity {
        case .working(let done, let total):
            return AppLocaleString.formatted("設定_路線_進捗_%d_%d", locale: locale, done, total)
        case .message(let text), .failed(let text):
            return text
        case .idle:
            if catalogSummary.routeCount == 0 {
                return AppLocaleString.text("設定_路線_未取得", locale: locale)
            }
            return AppLocaleString.formatted(
                "設定_路線_件数_%d_%d",
                locale: locale,
                catalogSummary.routeCount,
                catalogSummary.geometryCount
            )
        }
    }

    private var routeCatalogSection: some View {
        Section {
            Text(catalogStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                startCatalog(.download)
            } label: {
                Label(AppLocaleString.text("設定_路線_全件ダウンロード", locale: locale), systemImage: "arrow.down.circle")
            }
            .disabled(catalogBusy || !ThirdPartyDataConsent.isGranted)
            Button {
                startCatalog(.update)
            } label: {
                Label(AppLocaleString.text("設定_路線_更新", locale: locale), systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(catalogBusy || !ThirdPartyDataConsent.isGranted)
        } header: {
            Text(AppLocaleString.text("設定_路線データベース", locale: locale))
        } footer: {
            Text(AppLocaleString.text("設定_路線_フッター", locale: locale))
        }
    }

    private enum CatalogAction {
        case download
        case update
    }

    private func startCatalog(_ action: CatalogAction) {
        guard let coordinate = locationService.currentLocation else {
            catalogNote = AppLocaleString.text("設定_路線_現在地なし", locale: locale)
            return
        }
        catalogNote = nil
        switch action {
        case .download:
            catalogDownloader.downloadAll(near: coordinate)
        case .update:
            catalogDownloader.update(near: coordinate)
        }
    }
}
