import Foundation

extension Notification.Name {
    static let osmBusDataDeleted = Notification.Name("osmBus.dataDeleted")
    static let osmBusOpenAPISettings = Notification.Name("osmBus.openAPISettings")
}

enum ThirdPartyDataConsent {
    static let currentVersion = 1
    static let storageKey = "privacy.thirdPartyConsent.version"

    static var storedDecision: Int {
        UserDefaults.standard.integer(forKey: storageKey)
    }

    static var hasCurrentDecision: Bool {
        abs(storedDecision) == currentVersion
    }

    static var isGranted: Bool {
        storedDecision == currentVersion
    }

    static func grant() {
        UserDefaults.standard.set(currentVersion, forKey: storageKey)
    }

    static func decline() {
        UserDefaults.standard.set(-currentVersion, forKey: storageKey)
    }

    static func deleteDecision() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static var requiredMessage: String {
        AppLocaleString.currentText("第三者送信_同意が必要")
    }
}

enum AppDataDeletion {
    static func deleteAll() {
        DestinationHistoryStore.clearAll()
        SavedPlaceStore.clearAll()
        DestinationStore.save(nil)
        TransitRouteArchive.clear()
        BusLineMapStore.clear()
        GoogleRoutesAPIKeyStore.setUserConfiguredKey(nil)
        ThirdPartyDataConsent.deleteDecision()
        NotificationCenter.default.post(name: .osmBusDataDeleted, object: nil)
    }
}
