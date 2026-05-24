import SwiftUI

@main
struct OsmBusApp: App {
    @State private var pendingDeepLinkDestination: Destination?

    init() {
        UserDefaults.standard.register(defaults: [
            AppLanguage.storageKey: AppLanguage.english.rawValue,
            BusKeypadInputMode.storageKey: BusKeypadInputMode.appendToExisting.rawValue,
        ])
    }

    @AppStorage(AppLanguage.storageKey) private var appLanguageCode = AppLanguage.english.rawValue

    var body: some Scene {
        WindowGroup {
            MainView(pendingDeepLinkDestination: $pendingDeepLinkDestination)
                .environment(\.locale, Locale(identifier: appLanguageCode))
                .environment(ColorThemeManager.shared)
                .environment(AppAppearanceStore.shared)
                .environment(PlanStore.shared)
                .environment(SharedRoutesTrialStore.shared)
                .onOpenURL { url in
                    if let destination = OsmBusDeepLink.parseDestination(from: url) {
                        pendingDeepLinkDestination = destination
                    }
                }
        }
    }
}
