import SwiftUI

struct GoogleRoutesAPISettingsView: View {
    @AppStorage(GoogleRoutesAPIKeyStore.userDefaultsKey) private var storedAPIKey = ""
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

    private var trimmedDraft: String {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            apiIntroSection
            beginnerGuideSection
            apiRoleSection
            privacySection
            apiKeyInputSection
            testSection
            saveSection
        }
        .navigationTitle(AppLocaleString.text("Google Routes API", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveAPIKey()
                } label: {
                    Image(systemName: "checkmark")
                }
                .fontWeight(.semibold)
                .disabled(trimmedDraft.isEmpty)
                .accessibilityLabel(AppLocaleString.text("保存", locale: locale))
            }
        }
        .onAppear {
            reloadDraftFromStore()
        }
        .alert(AppLocaleString.text("保存しました", locale: locale), isPresented: $showSavedAlert) {
            Button(AppLocaleString.text("OK", locale: locale), role: .cancel) {}
        } message: {
            Text(AppLocaleString.text("osmBus_RoutesAPIキー保存完了", locale: locale))
        }
        .id(locale.identifier)
    }

    private func reloadDraftFromStore() {
        let saved = GoogleRoutesAPIKeyStore.userConfiguredKey()
        apiKeyDraft = saved ?? storedAPIKey
        hasSavedKey = GoogleRoutesAPIKeyStore.isConfigured
    }

    private var apiIntroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text(AppLocaleString.text("osmBus_RoutesAPI説明_リード", locale: locale))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(AppLocaleString.text("osmBus_RoutesAPI説明_補足", locale: locale))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text(AppLocaleString.text("osmBus_RoutesAPI_キーの役割", locale: locale))
                .textCase(nil)
        }
    }

    private var beginnerGuideSection: some View {
        Section {
            noticeRow(
                systemImage: "key.fill",
                tint: .orange,
                title: AppLocaleString.text("osmBus_RoutesAPI_初心者_これは何_見出し", locale: locale),
                text: AppLocaleString.text("osmBus_RoutesAPI_初心者_これは何", locale: locale)
            )
            noticeRow(
                systemImage: "gift.fill",
                tint: .green,
                title: AppLocaleString.text("osmBus_RoutesAPI_初心者_無料_見出し", locale: locale),
                text: AppLocaleString.text("osmBus_RoutesAPI_初心者_無料", locale: locale)
            )
            noticeRow(
                systemImage: "list.number",
                tint: .blue,
                title: AppLocaleString.text("osmBus_RoutesAPI_初心者_手順_見出し", locale: locale),
                text: AppLocaleString.text("osmBus_RoutesAPI_初心者_手順", locale: locale)
            )
        } header: {
            Text(AppLocaleString.text("osmBus_RoutesAPI_はじめて", locale: locale))
        }
    }

    private var apiRoleSection: some View {
        Section {
            noticeRow(
                systemImage: "bus.fill",
                tint: .blue,
                title: AppLocaleString.text("osmBus_RoutesAPI_バス判定タイトル", locale: locale),
                text: AppLocaleString.text("osmBus_RoutesAPI_バス判定説明", locale: locale)
            )
        }
    }

    private var privacySection: some View {
        Section {
            noticeRow(
                systemImage: "lock.shield.fill",
                tint: .teal,
                title: AppLocaleString.text("端末内のみ保存", locale: locale),
                text: AppLocaleString.text("osmBus_RoutesAPI_端末内説明", locale: locale)
            )
            noticeRow(
                systemImage: "arrow.up.right.circle.fill",
                tint: .blue,
                title: AppLocaleString.text("Google に直接送信", locale: locale),
                text: AppLocaleString.text("osmBus_RoutesAPI_Google送信説明", locale: locale)
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

                Button {
                    showingKey.toggle()
                } label: {
                    Image(systemName: showingKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(AppLocaleString.text("API キー", locale: locale))
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocaleString.text("osmBus_RoutesAPI_キー入力フッター", locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Link(
                    AppLocaleString.text("osmBus_RoutesAPI_キー取得リンク", locale: locale),
                    destination: URL(string: "https://console.cloud.google.com/apis/credentials")!
                )
                .font(.subheadline)
                Link(
                    AppLocaleString.text("osmBus_RoutesAPI_有効化手順", locale: locale),
                    destination: URL(string: "https://developers.google.com/maps/documentation/routes/cloud-setup")!
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
                    if isTesting {
                        ProgressView()
                    }
                }
            }
            .disabled(trimmedDraft.isEmpty || isTesting)

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
            Text(AppLocaleString.text("osmBus_RoutesAPI_導通テストフッター", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        if hasSavedKey {
            Section {
                Button(role: .destructive) {
                    GoogleRoutesAPIKeyStore.setUserConfiguredKey(nil)
                    storedAPIKey = ""
                    apiKeyDraft = ""
                    testResult = nil
                    hasSavedKey = false
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(AppLocaleString.text("osmBus_RoutesAPI_キー削除", locale: locale))
            }
        }
    }

    private func saveAPIKey() {
        GoogleRoutesAPIKeyStore.setUserConfiguredKey(trimmedDraft)
        storedAPIKey = trimmedDraft
        hasSavedKey = true
        showSavedAlert = true
    }

    private func noticeRow(systemImage: String, tint: Color, title: String, text: String) -> some View {
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

    private func runTest() async {
        isTesting = true
        testResult = nil

        let outcome = await GoogleRoutesAPIService.testConnection(apiKey: trimmedDraft)
        if outcome.isSuccess {
            testResult = .success(outcome.message)
        } else {
            testResult = .failure(outcome.message)
        }

        isTesting = false
    }
}

#Preview {
    AppSettingsView()
        .environment(ColorThemeManager.shared)
        .environment(AppAppearanceStore.shared)
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("API Settings") {
    NavigationStack {
        GoogleRoutesAPISettingsView()
            .environment(\.locale, Locale(identifier: "ja"))
    }
}
