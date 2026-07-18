import SwiftUI

enum PrivacyPolicyLinks {
    static let externalPolicy = URL(string: "https://docs.google.com/document/d/1ff8xnpmyj5UTW_OLLPKQo_s5DFJhnTefZvzdjASw0M4/edit?usp=sharing")!
    static let applePrivacy = URL(string: "https://www.apple.com/legal/privacy/")!
    static let appleMediaServicesTerms = URL(string: "https://www.apple.com/legal/internet-services/itunes/")!
    static let googlePrivacy = URL(string: "https://policies.google.com/privacy")!
}

struct PrivacyDataView: View {
    let requiresDecision: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @AppStorage(ThirdPartyDataConsent.storageKey) private var consentDecision = 0
    @State private var showsDeleteConfirmation = false

    init(requiresDecision: Bool = false) {
        self.requiresDecision = requiresDecision
    }

    var body: some View {
        List {
            if requiresDecision {
                Section {
                    Text(AppLocaleString.text("プライバシー_初回説明", locale: locale))
                        .font(.body.weight(.medium))
                }
            }

            Section(AppLocaleString.text("プライバシー_外部送信", locale: locale)) {
                disclosureRow(
                    "Google",
                    "プライバシー_Google詳細",
                    systemImage: "map.fill"
                )
                disclosureRow(
                    "Apple MapKit",
                    "プライバシー_Apple詳細",
                    systemImage: "apple.logo"
                )
                disclosureRow(
                    "OpenStreetMap / Overpass",
                    "プライバシー_Overpass詳細",
                    systemImage: "bus.fill"
                )
            }

            Section {
                Link(destination: PrivacyPolicyLinks.externalPolicy) {
                    Label(
                        AppLocaleString.text("プライバシー_ポリシー本文", locale: locale),
                        systemImage: "doc.text"
                    )
                }
            } footer: {
                Text(AppLocaleString.text("プライバシー_ポリシー本文_詳細", locale: locale))
            }

            Section {
                Link(destination: PrivacyPolicyLinks.applePrivacy) {
                    Label(
                        AppLocaleString.text("プライバシー_Appleポリシー", locale: locale),
                        systemImage: "apple.logo"
                    )
                }
                Link(destination: PrivacyPolicyLinks.appleMediaServicesTerms) {
                    Label(
                        AppLocaleString.text("プライバシー_Appleメディア規約", locale: locale),
                        systemImage: "apple.logo"
                    )
                }
                Link(destination: PrivacyPolicyLinks.googlePrivacy) {
                    Label(
                        AppLocaleString.text("プライバシー_Googleポリシー", locale: locale),
                        systemImage: "safari"
                    )
                }
            } header: {
                Text(AppLocaleString.text("プライバシー_関連ポリシー", locale: locale))
            } footer: {
                Text(AppLocaleString.text("プライバシー_関連ポリシー_詳細", locale: locale))
            }

            Section(AppLocaleString.text("プライバシー_端末保存", locale: locale)) {
                Text(AppLocaleString.text("プライバシー_保存詳細", locale: locale))
                Text(AppLocaleString.text("プライバシー_保持削除詳細", locale: locale))
            }

            Section("StoreKit") {
                Text(AppLocaleString.text("プライバシー_StoreKit詳細", locale: locale))
            }

            Section {
                if ThirdPartyDataConsent.isGranted {
                    Label(
                        AppLocaleString.text("プライバシー_同意中", locale: locale),
                        systemImage: "checkmark.shield.fill"
                    )
                    .foregroundStyle(.green)
                } else {
                    Label(
                        AppLocaleString.text("プライバシー_拒否中", locale: locale),
                        systemImage: "hand.raised.fill"
                    )
                    .foregroundStyle(.orange)
                }

                if !requiresDecision {
                    Button(ThirdPartyDataConsent.isGranted
                           ? AppLocaleString.text("プライバシー_同意撤回", locale: locale)
                           : AppLocaleString.text("プライバシー_同意する", locale: locale)) {
                        if ThirdPartyDataConsent.isGranted {
                            ThirdPartyDataConsent.decline()
                        } else {
                            ThirdPartyDataConsent.grant()
                        }
                        consentDecision = ThirdPartyDataConsent.storedDecision
                    }
                }
            } header: {
                Text(AppLocaleString.text("プライバシー_同意管理", locale: locale))
            } footer: {
                Text(AppLocaleString.text("プライバシー_拒否時説明", locale: locale))
            }

            if !requiresDecision {
                Section {
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label(
                            AppLocaleString.text("プライバシー_全データ削除", locale: locale),
                            systemImage: "trash"
                        )
                    }
                } footer: {
                    Text(AppLocaleString.text("プライバシー_全データ削除詳細", locale: locale))
                }
            }
        }
        .navigationTitle(AppLocaleString.text("プライバシーとデータ", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(requiresDecision)
        .safeAreaInset(edge: .bottom) {
            if requiresDecision {
                decisionButtons
            }
        }
        .toolbar {
            if !requiresDecision {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocaleString.text("完了", locale: locale)) { dismiss() }
                }
            }
        }
        .alert(
            AppLocaleString.text("プライバシー_全データ削除確認", locale: locale),
            isPresented: $showsDeleteConfirmation
        ) {
            Button(AppLocaleString.text("キャンセル", locale: locale), role: .cancel) {}
            Button(AppLocaleString.text("削除", locale: locale), role: .destructive) {
                AppDataDeletion.deleteAll()
                consentDecision = 0
            }
        } message: {
            Text(AppLocaleString.text("プライバシー_全データ削除詳細", locale: locale))
        }
    }

    private var decisionButtons: some View {
        VStack(spacing: 10) {
            Button {
                ThirdPartyDataConsent.grant()
                consentDecision = ThirdPartyDataConsent.storedDecision
            } label: {
                Text(AppLocaleString.text("プライバシー_同意して続ける", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                ThirdPartyDataConsent.decline()
                consentDecision = ThirdPartyDataConsent.storedDecision
            } label: {
                Text(AppLocaleString.text("プライバシー_同意しない", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.bar)
    }

    private func disclosureRow(_ title: String, _ detailKey: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(AppLocaleString.text(detailKey, locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
