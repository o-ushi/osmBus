import GoogleMaps
import SwiftUI
import UserNotifications

@main
struct OsmBusApp: App {
    @State private var pendingDeepLinkDestination: Destination?
    @AppStorage(ThirdPartyDataConsent.storageKey) private var consentDecision = 0

    init() {
        // userConfiguredKey() also performs the one-time UserDefaults → Keychain migration.
        let mapsKey = GoogleRoutesAPIKeyStore.userConfiguredKey() ?? Secrets.googleMapsAPIKey
        GMSServices.provideAPIKey(mapsKey)
        UserDefaults.standard.register(defaults: [
            AppLanguage.storageKey: AppLanguage.resolved(from: Locale.current).rawValue,
            BusKeypadInputMode.storageKey: BusKeypadInputMode.appendToExisting.rawValue,
        ])
        StopAlertSettings.registerDefaults()
        KeypadFeedbackSettings.registerDefaults()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @AppStorage(AppLanguage.storageKey) private var appLanguageCode = AppLanguage.english.rawValue

    var body: some Scene {
        WindowGroup {
            MainView(pendingDeepLinkDestination: $pendingDeepLinkDestination)
                .environment(\.locale, Locale(identifier: appLanguageCode))
                .environment(ColorThemeManager.shared)
                .environment(AppAppearanceStore.shared)
                .environment(PlanStore.shared)
                .environment(StorePurchaseManager.shared)
                .environment(SharedRoutesTrialStore.shared)
                .environment(SharedMapsTrialStore.shared)
                .task {
                    await StorePurchaseManager.shared.start()
                }
                .onOpenURL { url in
                    if let destination = OsmBusDeepLink.parseDestination(from: url) {
                        pendingDeepLinkDestination = destination
                    }
                }
                .fullScreenCover(
                    isPresented: Binding(
                        get: { abs(consentDecision) != ThirdPartyDataConsent.currentVersion },
                        set: { _ in }
                    )
                ) {
                    NavigationStack {
                        PrivacyDataView(requiresDecision: true)
                    }
                    .environment(\.locale, Locale(identifier: appLanguageCode))
                }
        }
    }
}
