import Foundation

enum GoogleMapsAPIService {
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case geocodeStatus(String, String?)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return AppLocaleString.currentText("URLの生成に失敗しました。")
            case .invalidResponse:
                return AppLocaleString.currentText("レスポンスの解析に失敗しました。")
            case .geocodeStatus(let status, let message):
                return Self.message(for: status, detail: message)
            }
        }

        private static func message(for status: String, detail: String?) -> String {
            switch status {
            case "REQUEST_DENIED":
                if let detail, !detail.isEmpty {
                    return AppLocaleString.currentFormatted("MapsAPI_エラー_拒否_%@", detail)
                }
                return AppLocaleString.currentText("MapsAPI_エラー_401")
            case "OVER_QUERY_LIMIT":
                return AppLocaleString.currentText("MapsAPI_エラー_429")
            case "INVALID_REQUEST":
                return AppLocaleString.currentText("MapsAPI_エラー_400")
            default:
                if let detail, !detail.isEmpty { return detail }
                return AppLocaleString.currentFormatted("MapsAPI_エラー_不明_%@", status)
            }
        }
    }

    enum TestOutcome: Equatable {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var message: String {
            switch self {
            case .success:
                return AppLocaleString.currentText("MapsAPI_接続成功")
            case .failure(let message):
                return message
            }
        }
    }

    /// 東京駅付近の逆ジオコーディングでキー有効性を確認（Routes API 導通テストと同様の REST 方式）
    static func testConnection(apiKey: String) async -> TestOutcome {
        switch await geocodeTest(apiKey: apiKey) {
        case .success:
            return .success
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }

    private static func geocodeTest(apiKey: String) async -> Result<Void, APIError> {
        guard ThirdPartyDataConsent.isGranted else {
            return .failure(.geocodeStatus("CONSENT_REQUIRED", ThirdPartyDataConsent.requiredMessage))
        }
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")
        components?.queryItems = [
            URLQueryItem(name: "latlng", value: "35.681236,139.767125"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "language", value: "ja"),
        ]
        guard let url = components?.url else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            switch http.statusCode {
            case 200:
                return parseGeocodeResponse(data)
            case 400:
                return .failure(.geocodeStatus("INVALID_REQUEST", nil))
            case 401, 403:
                return .failure(.geocodeStatus("REQUEST_DENIED", nil))
            case 429:
                return .failure(.geocodeStatus("OVER_QUERY_LIMIT", nil))
            case 500, 502, 503, 504:
                return .failure(.geocodeStatus("UNKNOWN_ERROR", AppLocaleString.currentText("MapsAPI_エラー_500")))
            default:
                let message = String(data: data, encoding: .utf8).map { String($0.prefix(160)) }
                return .failure(.geocodeStatus("HTTP_\(http.statusCode)", message))
            }
        } catch {
            return .failure(.geocodeStatus("NETWORK", APINetworkHelpers.friendlyNetworkMessage(for: error)))
        }
    }

    private static func parseGeocodeResponse(_ data: Data) -> Result<Void, APIError> {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["status"] as? String
        else {
            return .failure(.invalidResponse)
        }

        switch status {
        case "OK", "ZERO_RESULTS":
            return .success(())
        default:
            let detail = json["error_message"] as? String
            return .failure(.geocodeStatus(status, detail))
        }
    }

}
