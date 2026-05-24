import Foundation

enum RoutesAPIKeyResolver {
    enum Operation: Hashable {
        case busCheck(busNumber: String, destinationID: String)
        case transitRoutes(destinationID: String)
    }

    enum UnavailableReason {
        case trialExhausted
        case noKeyConfigured
    }

    enum Resolution {
        case userKey(String)
        case sharedTrialKey(String)
        case unavailable(UnavailableReason)

        var apiKey: String? {
            switch self {
            case .userKey(let key), .sharedTrialKey(let key):
                return key
            case .unavailable:
                return nil
            }
        }

        var unavailableReason: UnavailableReason? {
            if case .unavailable(let reason) = self { return reason }
            return nil
        }
    }

    @MainActor
    static func resolve(for operation: Operation, consumeTrial: Bool = true) -> Resolution {
        if let userKey = GoogleRoutesAPIKeyStore.userConfiguredKey() {
            return .userKey(userKey)
        }

        let sharedKey = Secrets.sharedGoogleRoutesAPIKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sharedKey.isEmpty else {
            return .unavailable(.noKeyConfigured)
        }

        let trialStore = SharedRoutesTrialStore.shared
        let signature = operationSignature(for: operation)

        if !consumeTrial {
            if trialStore.hasSessionSignature(signature) {
                return .sharedTrialKey(sharedKey)
            }
            return .unavailable(.noKeyConfigured)
        }

        guard trialStore.consumeTrialIfNeeded(signature: signature) else {
            return .unavailable(.trialExhausted)
        }

        return .sharedTrialKey(sharedKey)
    }

    @MainActor
    static func apiKey(for operation: Operation) -> String? {
        resolve(for: operation).apiKey
    }

    private static func operationSignature(for operation: Operation) -> String {
        switch operation {
        case .busCheck(let busNumber, let destinationID):
            return "bus|\(busNumber)|\(destinationID)"
        case .transitRoutes(let destinationID):
            return "routes|\(destinationID)"
        }
    }
}
