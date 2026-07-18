import Foundation

extension GoogleRoutesAPIService {
    static func driveFallback(apiKey: String) async -> TestOutcome {
        switch await computeRoutes(apiKey: apiKey, body: driveTestBody()) {
        case .success(let routes):
            return routes.isEmpty ? .failure(APIError.noRoutes.localizedDescription) : .apiKeyValidTransitUnavailable
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }

    static func transitRouteBody(
        originLatitude: Double,
        originLongitude: Double,
        destinationLatitude: Double,
        destinationLongitude: Double
    ) -> [String: Any] {
        let regionCode = regionCode(
            latitude: destinationLatitude,
            longitude: destinationLongitude
        )
        let languageCode = appLanguageCode(for: regionCode)

        return [
            "origin": waypointBody(latitude: originLatitude, longitude: originLongitude),
            "destination": waypointBody(latitude: destinationLatitude, longitude: destinationLongitude),
            "travelMode": "TRANSIT",
            "languageCode": languageCode,
            "regionCode": regionCode,
            "departureTime": transitDepartureTime(),
            "computeAlternativeRoutes": true,
            "transitPreferences": [
                "allowedTravelModes": ["BUS", "SUBWAY", "TRAIN", "LIGHT_RAIL", "RAIL"],
            ],
        ]
    }

    static func regionCode(latitude: Double, longitude: Double) -> String {
        if latitude >= 8.0, latitude <= 23.8, longitude >= 102.0, longitude <= 109.8 {
            return "VN"
        }
        if latitude >= 24.0, latitude <= 46.0, longitude >= 122.0, longitude <= 154.0 {
            return "JP"
        }
        return "US"
    }

    static func transitDepartureTime() -> String {
        let departure = Date().addingTimeInterval(60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: departure)
    }

    static func transitTestBody() -> [String: Any] {
        [
            "origin": ["address": "東京駅, 東京都千代田区"],
            "destination": ["address": "渋谷駅, 東京都渋谷区"],
            "travelMode": "TRANSIT",
            "languageCode": "ja",
            "regionCode": "JP",
            "departureTime": transitTestDepartureTime(),
            "computeAlternativeRoutes": true,
            "transitPreferences": [
                "allowedTravelModes": ["BUS", "SUBWAY", "TRAIN", "LIGHT_RAIL", "RAIL"],
            ],
        ]
    }

    static func driveTestBody() -> [String: Any] {
        [
            "origin": ["address": "東京駅, 東京都千代田区"],
            "destination": ["address": "渋谷駅, 東京都渋谷区"],
            "travelMode": "DRIVE",
            "languageCode": "ja",
            "regionCode": "JP",
        ]
    }

    static func waypointBody(latitude: Double, longitude: Double) -> [String: Any] {
        [
            "location": [
                "latLng": [
                    "latitude": latitude,
                    "longitude": longitude,
                ],
            ],
        ]
    }

    static func transitTestDepartureTime() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        var candidate = calendar.date(
            bySettingHour: 9,
            minute: 30,
            second: 0,
            of: Date()
        ) ?? Date()

        if candidate <= Date().addingTimeInterval(60 * 30) {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        while calendar.isDateInWeekend(candidate) {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: candidate)
    }

    static func computeRoutes(
        apiKey: String,
        body: [String: Any]
    ) async -> Result<[ParsedTransitRoute], APIError> {
        guard ThirdPartyDataConsent.isGranted else {
            return .failure(.httpError(statusCode: 0, message: ThirdPartyDataConsent.requiredMessage))
        }
        guard let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes") else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.timeoutInterval = 20

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.invalidResponse)
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            switch http.statusCode {
            case 200:
                return .success(parseRoutes(from: data))
            case 400:
                return .failure(.httpError(
                    statusCode: 400,
                    message: AppLocaleString.currentText("RoutesAPI_エラー_400")
                ))
            case 401, 403:
                return .failure(.httpError(
                    statusCode: http.statusCode,
                    message: AppLocaleString.currentText("RoutesAPI_エラー_401")
                ))
            case 429:
                return .failure(.httpError(
                    statusCode: 429,
                    message: AppLocaleString.currentText("RoutesAPI_エラー_429")
                ))
            case 500, 502, 503, 504:
                return .failure(.httpError(
                    statusCode: http.statusCode,
                    message: AppLocaleString.currentText("RoutesAPI_エラー_500")
                ))
            default:
                let message = String(data: data, encoding: .utf8).map { String($0.prefix(160)) }
                    ?? AppLocaleString.currentText("エラー_不明")
                return .failure(.httpError(statusCode: http.statusCode, message: message))
            }
        } catch {
            return .failure(.httpError(statusCode: 0, message: APINetworkHelpers.friendlyNetworkMessage(for: error)))
        }
    }

    static func computeRoutesWithRetry(
        apiKey: String,
        body: [String: Any]
    ) async -> Result<[ParsedTransitRoute], APIError> {
        let first = await computeRoutes(apiKey: apiKey, body: body)
        guard case .failure(let error) = first, error.isRetryable else {
            return first
        }

        try? await Task.sleep(nanoseconds: 600_000_000)
        return await computeRoutes(apiKey: apiKey, body: body)
    }

    static func parseRoutes(from data: Data) -> [ParsedTransitRoute] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]] else {
            return []
        }

        return routes.compactMap { routeJSON in
            guard let durationSeconds = parseDurationSeconds(routeJSON["duration"] as? String) else {
                return nil
            }

            let legs = routeJSON["legs"] as? [[String: Any]] ?? []
            let steps = legs.flatMap { leg in
                (leg["steps"] as? [[String: Any]] ?? []).compactMap(parseStep)
            }

            guard !steps.isEmpty else { return nil }
            let localizedValues = routeJSON["localizedValues"] as? [String: Any]
            let durationText = localizedText(from: localizedValues?["duration"])
            let advisory = routeJSON["travelAdvisory"] as? [String: Any]
            let fareText = localizedText(from: localizedValues?["transitFare"])
                ?? formattedFare(from: advisory)
            let fareAmount = numericFare(from: advisory)
            return ParsedTransitRoute(
                durationSeconds: durationSeconds,
                durationText: durationText,
                fareText: fareText,
                fareAmount: fareAmount,
                steps: steps
            )
        }
    }

    static func localizedText(from value: Any?) -> String? {
        guard let dictionary = value as? [String: Any],
              let text = dictionary["text"] as? String else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func formattedFare(from advisory: [String: Any]?) -> String? {
        guard let fare = advisory?["transitFare"] as? [String: Any],
              let currencyCode = fare["currencyCode"] as? String,
              let units = fare["units"] as? String else {
            return nil
        }
        let whole = Double(units) ?? 0
        let nanos = fare["nanos"] as? Int ?? 0
        let amount = whole + Double(nanos) / 1_000_000_000.0
        if amount.rounded() == amount {
            return "\(currencyCode) \(Int(amount))"
        }
        return String(format: "%@ %.2f", currencyCode, amount)
    }

    static func numericFare(from advisory: [String: Any]?) -> Double? {
        guard let fare = advisory?["transitFare"] as? [String: Any],
              let units = fare["units"] as? String,
              let whole = Double(units) else { return nil }
        let nanos = fare["nanos"] as? Int ?? 0
        return whole + Double(nanos) / 1_000_000_000.0
    }

    static func parseStep(_ stepJSON: [String: Any]) -> ParsedTransitStep? {
        let travelMode = stepJSON["travelMode"] as? String ?? ""
        let polylineJSON = stepJSON["polyline"] as? [String: Any]
        let encodedPolyline = polylineJSON?["encodedPolyline"] as? String
        let polylineCoordinates = encodedPolyline.map(decodePolyline) ?? []

        guard let transitDetails = stepJSON["transitDetails"] as? [String: Any] else {
            return ParsedTransitStep(
                travelMode: travelMode,
                lineName: nil,
                lineNameShort: nil,
                headsign: nil,
                vehicleType: nil,
                vehicleName: nil,
                departureStopName: nil,
                arrivalStopName: nil,
                polylineCoordinates: polylineCoordinates,
                departureStopLocation: nil,
                arrivalStopLocation: nil
            )
        }

        let transitLine = transitDetails["transitLine"] as? [String: Any]
        let vehicle = transitLine?["vehicle"] as? [String: Any]
        let stopDetails = transitDetails["stopDetails"] as? [String: Any]
        let departureStop = stopDetails?["departureStop"] as? [String: Any]
        let arrivalStop = stopDetails?["arrivalStop"] as? [String: Any]
        let vehicleName = (vehicle?["name"] as? [String: Any])?["text"] as? String

        return ParsedTransitStep(
            travelMode: travelMode,
            lineName: localizedText(from: transitLine?["name"]) ?? (transitLine?["name"] as? String),
            lineNameShort: localizedText(from: transitLine?["nameShort"]) ?? (transitLine?["nameShort"] as? String),
            headsign: localizedText(from: transitDetails["headsign"]) ?? (transitDetails["headsign"] as? String),
            vehicleType: vehicle?["type"] as? String,
            vehicleName: vehicleName,
            departureStopName: localizedText(from: departureStop?["name"]) ?? (departureStop?["name"] as? String),
            arrivalStopName: localizedText(from: arrivalStop?["name"]) ?? (arrivalStop?["name"] as? String),
            polylineCoordinates: polylineCoordinates,
            departureStopLocation: parseCoordinate(from: departureStop?["location"] as? [String: Any]),
            arrivalStopLocation: parseCoordinate(from: arrivalStop?["location"] as? [String: Any])
        )
    }

    static func parseCoordinate(from locationJSON: [String: Any]?) -> RouteCoordinate? {
        guard let latLng = locationJSON?["latLng"] as? [String: Any],
              let latitude = latLng["latitude"] as? Double,
              let longitude = latLng["longitude"] as? Double else {
            return nil
        }
        return RouteCoordinate(latitude: latitude, longitude: longitude)
    }

    static func parseDurationSeconds(_ raw: String?) -> TimeInterval? {
        guard let raw, raw.hasSuffix("s") else { return nil }
        let number = raw.dropLast()
        guard let seconds = Double(number) else { return nil }
        return seconds
    }
}
