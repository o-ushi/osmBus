import Foundation

enum APINetworkHelpers {
    static func friendlyNetworkMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return AppLocaleString.currentText("RoutesAPI_ネットワーク_オフライン")
            case .timedOut:
                return AppLocaleString.currentText("RoutesAPI_ネットワーク_タイムアウト")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return AppLocaleString.currentText("RoutesAPI_ネットワーク_接続不可")
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
