import Foundation

enum GoogleRoutesAPIService {
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int, message: String)
        case noRoutes

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return AppLocaleString.currentText("URLの生成に失敗しました。")
            case .invalidResponse:
                return AppLocaleString.currentText("レスポンスの解析に失敗しました。")
            case .httpError(let statusCode, let message):
                return AppLocaleString.currentFormatted("RoutesAPI_HTTP_%d_%@", statusCode, message)
            case .noRoutes:
                return AppLocaleString.currentText("この条件では公共交通ルートが見つかりませんでした。")
            }
        }

        var isRetryable: Bool {
            switch self {
            case .httpError(0, let message):
                return message.contains("タイムアウト")
                    || message.contains("接続")
                    || message.contains("Internet")
                    || message.contains("timed out")
            case .httpError(let statusCode, _):
                return [429, 500, 502, 503, 504].contains(statusCode)
            default:
                return false
            }
        }
    }

    enum TestOutcome: Equatable {
        case transitRouteFound
        case apiKeyValidTransitUnavailable
        case failure(String)

        var isSuccess: Bool {
            switch self {
            case .transitRouteFound, .apiKeyValidTransitUnavailable:
                return true
            case .failure:
                return false
            }
        }

        var message: String {
            switch self {
            case .transitRouteFound:
                return AppLocaleString.currentText("RoutesAPI_接続成功_公共交通")
            case .apiKeyValidTransitUnavailable:
                return AppLocaleString.currentText("RoutesAPI_接続成功_キー有効")
            case .failure(let message):
                return message
            }
        }
    }

    static let fieldMask = [
        "routes.duration",
        "routes.localizedValues.duration",
        "routes.localizedValues.transitFare",
        "routes.travelAdvisory.transitFare",
        "routes.legs.steps.travelMode",
        "routes.legs.steps.polyline.encodedPolyline",
        "routes.legs.steps.transitDetails",
        "routes.legs.steps.transitDetails.stopDetails.departureStop.location",
        "routes.legs.steps.transitDetails.stopDetails.arrivalStop.location",
    ].joined(separator: ",")

    static func testConnection(apiKey: String) async -> TestOutcome {
        switch await computeRoutes(apiKey: apiKey, body: transitTestBody()) {
        case .success(let routes):
            return routes.isEmpty ? await driveFallback(apiKey: apiKey) : .transitRouteFound
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }

    static func fetchTransitRoutes(
        originLatitude: Double,
        originLongitude: Double,
        destinationLatitude: Double,
        destinationLongitude: Double,
        apiKey: String
    ) async -> Result<[ParsedTransitRoute], APIError> {
        let body = transitRouteBody(
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude
        )
        switch await computeRoutesWithRetry(apiKey: apiKey, body: body) {
        case .success(let routes):
            return .success(routes)
        case .failure(let error):
            return .failure(error)
        }
    }

    static func appLanguageCode(for regionCode: String) -> String {
        let appCode = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.english.rawValue
        switch appCode {
        case AppLanguage.vietnamese.rawValue:
            return "vi"
        case AppLanguage.japanese.rawValue:
            return "ja"
        default:
            return regionCode == "VN" ? "vi" : "en"
        }
    }
}
