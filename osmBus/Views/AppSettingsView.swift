import SwiftUI

private enum AppSettingsRoute: Hashable {
    case apiSettings
    case alertSettings
    case privacyData
}

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(ColorThemeManager.self) private var themeManager

    @AppStorage(AppLanguage.storageKey) private var appLanguageCode = AppLanguage.english.rawValue
    @AppStorage(BusKeypadInputMode.storageKey) private var busKeypadInputModeRaw =
        BusKeypadInputMode.appendToExisting.rawValue
    @AppStorage(KeypadHapticManager.hapticEnabledKey)   private var hapticEnabled   = true
    @AppStorage(KeypadHapticManager.hapticIntensityKey) private var hapticIntensityRaw = "medium"
    @AppStorage(KeypadHapticManager.soundEnabledKey)    private var soundEnabled    = false
    @AppStorage(KeypadHapticManager.soundVolumeKey)     private var soundVolume     = 0.5
    @State private var path = NavigationPath()

    var opensAPISettingsOnAppear = false

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageCode) ?? .english
    }

    private var currentBusKeypadInputMode: BusKeypadInputMode {
        BusKeypadInputMode(rawValue: busKeypadInputModeRaw) ?? .appendToExisting
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

                Section {
                    ForEach(ColorTheme.allCases) { theme in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                themeManager.changeTheme(to: theme)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                HStack(spacing: 5) {
                                    ForEach(theme.previewColors, id: \.self) { color in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color)
                                            .frame(width: 18, height: 36)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppLocaleString.text(theme.displayName, locale: locale))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .fontWeight(themeManager.currentTheme == theme ? .semibold : .regular)
                                    Text(AppLocaleString.text(theme.themeDescription, locale: locale))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if themeManager.currentTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(AppLocaleString.text("カラーテーマ", locale: locale))
                }

                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                            .environment(AppAppearanceStore.shared)
                            .environment(\.locale, locale)
                    } label: {
                        Label(AppLocaleString.text("外観", locale: locale), systemImage: "paintbrush.pointed.fill")
                    }
                } header: {
                    Text(AppLocaleString.text("見た目", locale: locale))
                }

                if PlanStore.shared.isPaid {
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
                guard opensAPISettingsOnAppear, path.isEmpty else { return }
                path.append(AppSettingsRoute.apiSettings)
            }
            .id(locale.identifier)
        }
        .environment(\.locale, locale)
    }
}
