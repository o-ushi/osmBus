import GoogleMaps
import SwiftUI

struct GoogleAPISettingsConfiguration {
    struct Strings {
        let navigationTitleKey: String
        let savedMessageKey: String
        let introLeadKey: String
        let introSupplementKey: String
        let roleHeaderKey: String
        let beginnerHeaderKey: String
        let beginnerWhatTitleKey: String
        let beginnerWhatBodyKey: String
        let beginnerFreeTitleKey: String
        let beginnerFreeBodyKey: String
        let beginnerStepsTitleKey: String
        let beginnerStepsBodyKey: String
        let deviceStorageBodyKey: String
        let googleSendBodyKey: String
        let keyInputFooterKey: String
        let keyObtainLinkKey: String
        let activationGuideKey: String
        let testFooterKey: String
        let deleteKeyKey: String
        let premiumOnlyBodyKey: String
        let roleTitleKey: String?
        let roleBodyKey: String?
    }

    let strings: Strings
    let credentialsURL: URL
    let setupGuideURL: URL
    let requiresKeyFormatValidation: Bool
    let loadUserKey: () -> String?
    let saveUserKey: (String) -> Void
    let deleteUserKey: () -> Void
    let hasUserConfiguredKey: () -> Bool
    let testConnection: (String) async -> (success: Bool, message: String)
    let onAfterSave: ((String) -> Void)?
    let onAfterDelete: (() -> Void)?
}

struct GoogleAPISettingsView<StatusSection: View>: View {
    let config: GoogleAPISettingsConfiguration
    let onAfterDelete: (() -> Void)?
    @ViewBuilder let statusSection: () -> StatusSection

    @Environment(\.locale) private var locale
    @State private var apiKeyDraft = ""
    @State private var showingKey = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var hasSavedKey = false
    @State private var showSavedAlert = false

    private enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

    init(
        config: GoogleAPISettingsConfiguration,
        onAfterDelete: (() -> Void)? = nil,
        @ViewBuilder statusSection: @escaping () -> StatusSection
    ) {
        self.config = config
        self.onAfterDelete = onAfterDelete
        self.statusSection = statusSection
    }

    private var trimmedDraft: String {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isKeyFormatValid: Bool {
        guard config.requiresKeyFormatValidation else { return true }
        return trimmedDraft.hasPrefix("AIzaSy") && trimmedDraft.count >= 35
    }

    var body: some View {
        Form {
            statusSection()
            apiIntroSection
            beginnerGuideSection
            if let roleTitleKey = config.strings.roleTitleKey,
               let roleBodyKey = config.strings.roleBodyKey {
                roleSection(titleKey: roleTitleKey, bodyKey: roleBodyKey)
            }
            privacySection
            if PlanStore.shared.isPaid {
                apiKeyInputSection
                testSection
                if hasSavedKey { deleteSection }
            } else {
                premiumOnlyAPIKeySection
            }
        }
        .navigationTitle(AppLocaleString.text(config.strings.navigationTitleKey, locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenBackButtonWithSwipe()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if PlanStore.shared.isPaid {
                    Button { saveAPIKey() } label: {
                        Image(systemName: "checkmark")
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedDraft.isEmpty || !isKeyFormatValid)
                    .accessibilityLabel(AppLocaleString.text("保存", locale: locale))
                }
            }
        }
        .onAppear { reloadDraft() }
        .alert(AppLocaleString.text("保存しました", locale: locale), isPresented: $showSavedAlert) {
            Button(AppLocaleString.text("OK", locale: locale), role: .cancel) {}
        } message: {
            Text(AppLocaleString.text(config.strings.savedMessageKey, locale: locale))
        }
        .id(locale.identifier)
    }

    private func reloadDraft() {
        let saved = config.loadUserKey()
        apiKeyDraft = saved ?? ""
        hasSavedKey = config.hasUserConfiguredKey()
    }

    private var apiIntroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text(AppLocaleString.text(config.strings.introLeadKey, locale: locale))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(AppLocaleString.text(config.strings.introSupplementKey, locale: locale))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text(AppLocaleString.text(config.strings.roleHeaderKey, locale: locale))
                .textCase(nil)
        }
    }

    private var beginnerGuideSection: some View {
        Section {
            SettingsNoticeRow(
                systemImage: "key.fill",
                tint: .orange,
                title: AppLocaleString.text(config.strings.beginnerWhatTitleKey, locale: locale),
                text: AppLocaleString.text(config.strings.beginnerWhatBodyKey, locale: locale)
            )
            SettingsNoticeRow(
                systemImage: "gift.fill",
                tint: .green,
                title: AppLocaleString.text(config.strings.beginnerFreeTitleKey, locale: locale),
                text: AppLocaleString.text(config.strings.beginnerFreeBodyKey, locale: locale)
            )
            SettingsNoticeRow(
                systemImage: "list.number",
                tint: .blue,
                title: AppLocaleString.text(config.strings.beginnerStepsTitleKey, locale: locale),
                text: AppLocaleString.text(config.strings.beginnerStepsBodyKey, locale: locale)
            )
        } header: {
            Text(AppLocaleString.text(config.strings.beginnerHeaderKey, locale: locale))
        }
    }

    private func roleSection(titleKey: String, bodyKey: String) -> some View {
        Section {
            SettingsNoticeRow(
                systemImage: "bus.fill",
                tint: .blue,
                title: AppLocaleString.text(titleKey, locale: locale),
                text: AppLocaleString.text(bodyKey, locale: locale)
            )
        }
    }

    private var privacySection: some View {
        Section {
            SettingsNoticeRow(
                systemImage: "lock.shield.fill",
                tint: .teal,
                title: AppLocaleString.text("端末内のみ保存", locale: locale),
                text: AppLocaleString.text(config.strings.deviceStorageBodyKey, locale: locale)
            )
            SettingsNoticeRow(
                systemImage: "arrow.up.right.circle.fill",
                tint: .blue,
                title: AppLocaleString.text("Google に直接送信", locale: locale),
                text: AppLocaleString.text(config.strings.googleSendBodyKey, locale: locale)
            )
        } header: {
            Text(AppLocaleString.text("プライバシーとセキュリティ", locale: locale))
        }
    }

    private var apiKeyInputSection: some View {
        Section {
            HStack {
                Group {
                    if showingKey {
                        TextField("AIzaSy...", text: $apiKeyDraft)
                    } else {
                        SecureField("AIzaSy...", text: $apiKeyDraft)
                    }
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))

                if config.requiresKeyFormatValidation, !trimmedDraft.isEmpty {
                    Image(systemName: isKeyFormatValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isKeyFormatValid ? .green : .red)
                        .font(.body)
                }

                Button { showingKey.toggle() } label: {
                    Image(systemName: showingKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(AppLocaleString.text("API キー", locale: locale))
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocaleString.text(config.strings.keyInputFooterKey, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Link(
                    AppLocaleString.text(config.strings.keyObtainLinkKey, locale: locale),
                    destination: config.credentialsURL
                )
                .font(.subheadline)
                Link(
                    AppLocaleString.text(config.strings.activationGuideKey, locale: locale),
                    destination: config.setupGuideURL
                )
                .font(.subheadline)
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                Task { await runTest() }
            } label: {
                HStack {
                    Label(AppLocaleString.text("導通テスト", locale: locale), systemImage: "network")
                    Spacer()
                    if isTesting { ProgressView() }
                }
            }
            .disabled(trimmedDraft.isEmpty || isTesting || !isKeyFormatValid)

            if let testResult {
                switch testResult {
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.footnote)
                case .failure(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        } footer: {
            Text(AppLocaleString.text(config.strings.testFooterKey, locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                config.deleteUserKey()
                apiKeyDraft = ""
                testResult = nil
                hasSavedKey = false
                onAfterDelete?()
                config.onAfterDelete?()
            } label: {
                Label(
                    AppLocaleString.text(config.strings.deleteKeyKey, locale: locale),
                    systemImage: "trash"
                )
            }
        }
    }

    private var premiumOnlyAPIKeySection: some View {
        Section {
            SettingsNoticeRow(
                systemImage: "crown.fill",
                tint: .yellow,
                title: AppLocaleString.text("APIキー_Premium限定_タイトル", locale: locale),
                text: AppLocaleString.text(config.strings.premiumOnlyBodyKey, locale: locale)
            )
        } header: {
            Text(AppLocaleString.text("API キー", locale: locale))
        }
    }

    private func saveAPIKey() {
        config.saveUserKey(trimmedDraft)
        config.onAfterSave?(trimmedDraft)
        hasSavedKey = true
        showSavedAlert = true
    }

    private func runTest() async {
        isTesting = true
        testResult = nil
        let outcome = await config.testConnection(trimmedDraft)
        testResult = outcome.success ? .success(outcome.message) : .failure(outcome.message)
        isTesting = false
    }
}

enum GoogleAPISettingsConfigurations {
    /// Routes API・Maps SDK 共通の統合 API キー設定。
    static let routes = GoogleAPISettingsConfiguration(
        strings: .init(
            navigationTitleKey: "Google API",
            savedMessageKey: "RoutesAPIキー保存完了",
            introLeadKey: "RoutesAPI説明_リード",
            introSupplementKey: "RoutesAPI説明_補足",
            roleHeaderKey: "RoutesAPI_キーの役割",
            beginnerHeaderKey: "RoutesAPI_はじめて",
            beginnerWhatTitleKey: "RoutesAPI_初心者_これは何_見出し",
            beginnerWhatBodyKey: "RoutesAPI_初心者_これは何",
            beginnerFreeTitleKey: "RoutesAPI_初心者_無料_見出し",
            beginnerFreeBodyKey: "RoutesAPI_初心者_無料",
            beginnerStepsTitleKey: "RoutesAPI_初心者_手順_見出し",
            beginnerStepsBodyKey: "RoutesAPI_初心者_手順",
            deviceStorageBodyKey: "RoutesAPI_端末内説明",
            googleSendBodyKey: "RoutesAPI_Google送信説明",
            keyInputFooterKey: "RoutesAPI_キー入力フッター",
            keyObtainLinkKey: "RoutesAPI_キー取得リンク",
            activationGuideKey: "RoutesAPI_有効化手順",
            testFooterKey: "RoutesAPI_導通テストフッター",
            deleteKeyKey: "RoutesAPI_キー削除",
            premiumOnlyBodyKey: "APIキー_Premium限定_説明",
            roleTitleKey: "RoutesAPI_バス判定タイトル",
            roleBodyKey: "RoutesAPI_バス判定説明"
        ),
        credentialsURL: URL(string: "https://console.cloud.google.com/apis/credentials")!,
        setupGuideURL: URL(string: "https://developers.google.com/maps/documentation/routes/cloud-setup")!,
        requiresKeyFormatValidation: true,
        loadUserKey: { GoogleRoutesAPIKeyStore.userConfiguredKey() },
        saveUserKey: { GoogleRoutesAPIKeyStore.setUserConfiguredKey($0) },
        deleteUserKey: { GoogleRoutesAPIKeyStore.setUserConfiguredKey(nil) },
        hasUserConfiguredKey: { GoogleRoutesAPIKeyStore.isConfigured },
        testConnection: { apiKey in
            let outcome = await GoogleRoutesAPIService.testConnection(apiKey: apiKey)
            return (outcome.isSuccess, outcome.message)
        },
        onAfterSave: { GMSServices.provideAPIKey($0) },
        onAfterDelete: nil
    )
}
