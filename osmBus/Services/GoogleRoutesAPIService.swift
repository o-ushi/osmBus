import Foundation

struct RouteCoordinate: Sendable, Hashable {
    let latitude: Double
    let longitude: Double
}

struct ParsedTransitStep: Sendable {
    let travelMode: String
    let lineName: String?
    let lineNameShort: String?
    let headsign: String?
    let vehicleType: String?
    let vehicleName: String?
    let departureStopName: String?
    let arrivalStopName: String?
    let stopCount: Int?
    let polylineCoordinates: [RouteCoordinate]
    let departureStopLocation: RouteCoordinate?
    let arrivalStopLocation: RouteCoordinate?
}

struct ParsedTransitRoute: Sendable {
    let durationSeconds: TimeInterval
    let durationText: String?
    let fareText: String?
    let steps: [ParsedTransitStep]
}

enum BusCheckOutcome: Equatable {
    case boardAll(arrivalText: String, alightStopText: String)
    case boardIfVariant(names: [String], arrivalText: String, alightStopText: String)
    case doNotBoard
    case noTransitRoutes
    case configurationError(String)
    case apiError(String)
}

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
                return AppLocaleString.currentFormatted("osmBus_RoutesAPI_HTTP_%d_%@", statusCode, message)
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
                return AppLocaleString.currentText("osmBus_RoutesAPI_接続成功_公共交通")
            case .apiKeyValidTransitUnavailable:
                return AppLocaleString.currentText("osmBus_RoutesAPI_接続成功_キー有効")
            case .failure(let message):
                return message
            }
        }
    }

    private static let fieldMask = [
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

    static func checkBus(
        busNumber: String,
        originLatitude: Double,
        originLongitude: Double,
        destination: Destination,
        apiKey: String
    ) async -> BusCheckOutcome {
        let trimmedBusNumber = busNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBusNumber.isEmpty else {
            return .configurationError(AppLocaleString.currentText("osmBus_エラー_バス番号未入力"))
        }

        let distanceMeters = Self.distanceMeters(
            fromLatitude: originLatitude,
            fromLongitude: originLongitude,
            toLatitude: destination.latitude,
            toLongitude: destination.longitude
        )
        if distanceMeters > 80_000 {
            return .configurationError(
                AppLocaleString.currentFormatted(
                    "osmBus_エラー_距離超過_%d",
                    Int(distanceMeters / 1000)
                )
            )
        }

        let body = transitRouteBody(
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destinationLatitude: destination.latitude,
            destinationLongitude: destination.longitude
        )

        switch await computeRoutesWithRetry(apiKey: apiKey, body: body) {
        case .failure(let error):
            return .apiError(error.localizedDescription)
        case .success(let routes):
            guard !routes.isEmpty else { return .noTransitRoutes }
            return evaluateBusQuery(trimmedBusNumber, routes: routes)
        }
    }

    private static func evaluateBusQuery(_ query: String, routes: [ParsedTransitRoute]) -> BusCheckOutcome {
        if query.allSatisfy(\.isNumber) {
            return evaluateNumericBusQuery(query, routes: routes)
        }

        if let match = findMatchingRoute(routes: routes, busNumber: query) {
            return boardOutcome(for: query, route: match)
        }
        return .doNotBoard
    }

    private static func evaluateNumericBusQuery(
        _ numericQuery: String,
        routes: [ParsedTransitRoute]
    ) -> BusCheckOutcome {
        let candidates = discoverBusCandidates(in: routes, numericQuery: numericQuery)
        let workingVariants = candidates.filter { findMatchingRoute(routes: routes, busNumber: $0) != nil }

        if candidates.isEmpty {
            if let match = findMatchingRoute(routes: routes, busNumber: numericQuery) {
                return boardOutcome(for: numericQuery, route: match)
            }
            return .doNotBoard
        }

        if workingVariants.count == candidates.count {
            guard let primary = workingVariants.first,
                  let match = findMatchingRoute(routes: routes, busNumber: primary) else {
                return .doNotBoard
            }
            return boardOutcome(for: primary, route: match)
        }

        if workingVariants.count == 1, let variant = workingVariants.first,
           let match = findMatchingRoute(routes: routes, busNumber: variant) {
            return variantOutcome(for: [variant], route: match)
        }

        if workingVariants.count > 1, let primary = workingVariants.first,
           let match = findMatchingRoute(routes: routes, busNumber: primary) {
            return variantOutcome(for: workingVariants, route: match)
        }

        return .doNotBoard
    }

    private static func boardOutcome(for busNumber: String, route: ParsedTransitRoute) -> BusCheckOutcome {
        .boardAll(
            arrivalText: AppLocaleString.currentFormatted(
                "osmBus_到着予定_%@",
                formatArrivalTime(after: route.durationSeconds)
            ),
            alightStopText: alightStopText(for: route, busNumber: busNumber)
        )
    }

    private static func variantOutcome(
        for names: [String],
        route: ParsedTransitRoute
    ) -> BusCheckOutcome {
        guard let primary = names.first else { return .doNotBoard }
        return .boardIfVariant(
            names: names,
            arrivalText: AppLocaleString.currentFormatted(
                "osmBus_到着予定_%@",
                formatArrivalTime(after: route.durationSeconds)
            ),
            alightStopText: alightStopText(for: route, busNumber: primary)
        )
    }

    static func discoverBusCandidates(in routes: [ParsedTransitRoute], numericQuery: String) -> [String] {
        guard numericQuery.allSatisfy(\.isNumber),
              let queryParts = parseBusIdentifierParts(numericQuery) else {
            return []
        }

        var tokens = Set<String>()
        for route in routes {
            for step in route.steps where isBusStep(step) {
                for text in [step.lineNameShort, step.lineName, step.headsign, step.vehicleName] {
                    guard let text else { continue }
                    for token in extractBusTokens(from: text) where token.compactNumber == queryParts.compactNumber {
                        tokens.insert(token.displayToken)
                    }
                }
            }
        }

        return sortBusTokens(Array(tokens))
    }

    private static func extractBusTokens(from text: String) -> [BusIdentifierParts] {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else { return [] }

        guard let regex = try? NSRegularExpression(pattern: #"([A-Z]{0,2}\d{1,4}[A-Z]{0,2})"#) else {
            return []
        }

        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        return regex.matches(in: normalized, range: range).compactMap { match in
            guard let tokenRange = Range(match.range(at: 1), in: normalized) else { return nil }
            return parseBusIdentifierParts(String(normalized[tokenRange]))
        }
    }

    private struct BusIdentifierParts {
        let prefix: String
        let number: String
        let suffix: String

        var displayToken: String {
            prefix + number + suffix
        }

        var compactNumber: String {
            String(Int(number) ?? 0)
        }
    }

    private static func parseBusIdentifierParts(_ raw: String) -> BusIdentifierParts? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let regex = try? NSRegularExpression(pattern: #"^([A-Z]{0,2})(\d{1,4})([A-Z]{0,2})$"#),
              let match = regex.firstMatch(
                  in: normalized,
                  range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
              ),
              let prefixRange = Range(match.range(at: 1), in: normalized),
              let numberRange = Range(match.range(at: 2), in: normalized),
              let suffixRange = Range(match.range(at: 3), in: normalized) else {
            return nil
        }

        return BusIdentifierParts(
            prefix: String(normalized[prefixRange]),
            number: String(normalized[numberRange]),
            suffix: String(normalized[suffixRange])
        )
    }

    private static func sortBusTokens(_ tokens: [String]) -> [String] {
        tokens.sorted { lhs, rhs in
            let left = parseBusIdentifierParts(lhs)
            let right = parseBusIdentifierParts(rhs)

            switch (left?.compactNumber, right?.compactNumber) {
            case let (l?, r?) where l != r:
                return (Int(l) ?? 0) < (Int(r) ?? 0)
            default:
                break
            }

            if (left?.prefix ?? "") != (right?.prefix ?? "") {
                return (left?.prefix ?? "") < (right?.prefix ?? "")
            }

            return (left?.suffix ?? "") < (right?.suffix ?? "")
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

    private static func driveFallback(apiKey: String) async -> TestOutcome {
        switch await computeRoutes(apiKey: apiKey, body: driveTestBody()) {
        case .success(let routes):
            return routes.isEmpty ? .failure(APIError.noRoutes.localizedDescription) : .apiKeyValidTransitUnavailable
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }

    private static func transitRouteBody(
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

    private static func regionCode(latitude: Double, longitude: Double) -> String {
        if latitude >= 8.0, latitude <= 23.8, longitude >= 102.0, longitude <= 109.8 {
            return "VN"
        }
        if latitude >= 24.0, latitude <= 46.0, longitude >= 122.0, longitude <= 154.0 {
            return "JP"
        }
        return "US"
    }

    private static func transitDepartureTime() -> String {
        let departure = Date().addingTimeInterval(60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: departure)
    }

    private static func distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let originLat = fromLatitude * .pi / 180
        let originLon = fromLongitude * .pi / 180
        let destinationLat = toLatitude * .pi / 180
        let destinationLon = toLongitude * .pi / 180
        let deltaLat = destinationLat - originLat
        let deltaLon = destinationLon - originLon

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(originLat) * cos(destinationLat) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    private static func transitTestBody() -> [String: Any] {
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

    private static func driveTestBody() -> [String: Any] {
        [
            "origin": ["address": "東京駅, 東京都千代田区"],
            "destination": ["address": "渋谷駅, 東京都渋谷区"],
            "travelMode": "DRIVE",
            "languageCode": "ja",
            "regionCode": "JP",
        ]
    }

    private static func waypointBody(latitude: Double, longitude: Double) -> [String: Any] {
        [
            "location": [
                "latLng": [
                    "latitude": latitude,
                    "longitude": longitude,
                ],
            ],
        ]
    }

    private static func transitTestDepartureTime() -> String {
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

    private static func computeRoutes(
        apiKey: String,
        body: [String: Any]
    ) async -> Result<[ParsedTransitRoute], APIError> {
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
                    message: AppLocaleString.currentText("osmBus_RoutesAPI_エラー_400")
                ))
            case 401, 403:
                return .failure(.httpError(
                    statusCode: http.statusCode,
                    message: AppLocaleString.currentText("osmBus_RoutesAPI_エラー_401")
                ))
            case 429:
                return .failure(.httpError(
                    statusCode: 429,
                    message: AppLocaleString.currentText("osmBus_RoutesAPI_エラー_429")
                ))
            case 500, 502, 503, 504:
                return .failure(.httpError(
                    statusCode: http.statusCode,
                    message: AppLocaleString.currentText("osmBus_RoutesAPI_エラー_500")
                ))
            default:
                let message = String(data: data, encoding: .utf8).map { String($0.prefix(160)) } ?? "不明なエラー"
                return .failure(.httpError(statusCode: http.statusCode, message: message))
            }
        } catch {
            return .failure(.httpError(statusCode: 0, message: friendlyNetworkMessage(for: error)))
        }
    }

    private static func computeRoutesWithRetry(
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

    private static func friendlyNetworkMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return AppLocaleString.currentText("osmBus_RoutesAPI_ネットワーク_オフライン")
            case .timedOut:
                return AppLocaleString.currentText("osmBus_RoutesAPI_ネットワーク_タイムアウト")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return AppLocaleString.currentText("osmBus_RoutesAPI_ネットワーク_接続不可")
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private static func parseRoutes(from data: Data) -> [ParsedTransitRoute] {
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
            let fareText = localizedText(from: localizedValues?["transitFare"])
                ?? formattedFare(from: routeJSON["travelAdvisory"] as? [String: Any])
            return ParsedTransitRoute(
                durationSeconds: durationSeconds,
                durationText: durationText,
                fareText: fareText,
                steps: steps
            )
        }
    }

    static func displayDuration(for route: ParsedTransitRoute, locale: Locale) -> String {
        if let durationText = route.durationText, !durationText.isEmpty {
            return durationText
        }
        let minutes = max(1, Int((route.durationSeconds / 60.0).rounded()))
        return AppLocaleString.formatted("osmBus_所要時間_%d分", locale: locale, minutes)
    }

    static func displayFare(for route: ParsedTransitRoute) -> String? {
        guard let fareText = route.fareText, !fareText.isEmpty else { return nil }
        return fareText
    }

    static func transitLineSummary(for route: ParsedTransitRoute) -> String {
        let lines = route.steps.compactMap { step -> String? in
            guard step.travelMode == "TRANSIT" else { return nil }
            if let short = step.lineNameShort, !short.isEmpty { return short }
            if let name = step.lineName, !name.isEmpty { return name }
            if let vehicle = step.vehicleName, !vehicle.isEmpty { return vehicle }
            return step.vehicleType
        }
        if lines.isEmpty {
            return AppLocaleString.currentText("osmBus_公共交通ステップなし")
        }
        return lines.joined(separator: " → ")
    }

    private static func localizedText(from value: Any?) -> String? {
        guard let dictionary = value as? [String: Any],
              let text = dictionary["text"] as? String else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func formattedFare(from advisory: [String: Any]?) -> String? {
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

    private static func parseStep(_ stepJSON: [String: Any]) -> ParsedTransitStep? {
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
                stopCount: nil,
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
            lineName: transitLine?["name"] as? String,
            lineNameShort: transitLine?["nameShort"] as? String,
            headsign: transitDetails["headsign"] as? String,
            vehicleType: vehicle?["type"] as? String,
            vehicleName: vehicleName,
            departureStopName: departureStop?["name"] as? String,
            arrivalStopName: arrivalStop?["name"] as? String,
            stopCount: transitDetails["stopCount"] as? Int,
            polylineCoordinates: polylineCoordinates,
            departureStopLocation: parseCoordinate(from: departureStop?["location"] as? [String: Any]),
            arrivalStopLocation: parseCoordinate(from: arrivalStop?["location"] as? [String: Any])
        )
    }

    private static func parseCoordinate(from locationJSON: [String: Any]?) -> RouteCoordinate? {
        guard let latLng = locationJSON?["latLng"] as? [String: Any],
              let latitude = latLng["latitude"] as? Double,
              let longitude = latLng["longitude"] as? Double else {
            return nil
        }
        return RouteCoordinate(latitude: latitude, longitude: longitude)
    }

    private static func decodePolyline(_ encoded: String) -> [RouteCoordinate] {
        var coordinates: [RouteCoordinate] = []
        var index = encoded.startIndex
        var latitude = 0
        var longitude = 0

        while index < encoded.endIndex {
            var result = 0
            var shift = 0
            var byte: Int

            repeat {
                guard index < encoded.endIndex else { return coordinates }
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let deltaLatitude = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            latitude += deltaLatitude

            result = 0
            shift = 0

            repeat {
                guard index < encoded.endIndex else { return coordinates }
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let deltaLongitude = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            longitude += deltaLongitude

            coordinates.append(
                RouteCoordinate(
                    latitude: Double(latitude) / 100_000.0,
                    longitude: Double(longitude) / 100_000.0
                )
            )
        }

        return coordinates
    }

    static func routeHasMapGeometry(_ route: ParsedTransitRoute) -> Bool {
        route.steps.contains { !$0.polylineCoordinates.isEmpty || $0.departureStopLocation != nil }
    }

    /// Routes API は乗降停留所のみ返すため、ポリライン上に stopCount 分の中間停を均等配置する。
    static func interpolatedStopCoordinates(
        along polyline: [RouteCoordinate],
        stopCount: Int
    ) -> [RouteCoordinate] {
        guard stopCount > 0, polyline.count >= 2 else { return [] }

        let coordinates = polyline
        var segmentLengths: [Double] = []
        var totalLength = 0.0

        for index in 0..<(coordinates.count - 1) {
            let length = distanceMeters(
                fromLatitude: coordinates[index].latitude,
                fromLongitude: coordinates[index].longitude,
                toLatitude: coordinates[index + 1].latitude,
                toLongitude: coordinates[index + 1].longitude
            )
            segmentLengths.append(length)
            totalLength += length
        }

        guard totalLength > 0 else { return [] }

        return (1...stopCount).map { stopIndex in
            let targetDistance = totalLength * Double(stopIndex) / Double(stopCount + 1)
            return coordinate(atDistance: targetDistance, on: coordinates, segmentLengths: segmentLengths)
        }
    }

    static func midpointCoordinate(on polyline: [RouteCoordinate]) -> RouteCoordinate? {
        guard polyline.count >= 2 else { return polyline.first }

        var segmentLengths: [Double] = []
        var totalLength = 0.0

        for index in 0..<(polyline.count - 1) {
            let length = distanceMeters(
                fromLatitude: polyline[index].latitude,
                fromLongitude: polyline[index].longitude,
                toLatitude: polyline[index + 1].latitude,
                toLongitude: polyline[index + 1].longitude
            )
            segmentLengths.append(length)
            totalLength += length
        }

        guard totalLength > 0 else { return polyline.first }
        return coordinate(atDistance: totalLength / 2, on: polyline, segmentLengths: segmentLengths)
    }

    private static func coordinate(
        atDistance targetDistance: Double,
        on polyline: [RouteCoordinate],
        segmentLengths: [Double]
    ) -> RouteCoordinate {
        var remaining = targetDistance

        for index in 0..<segmentLengths.count {
            let segmentLength = segmentLengths[index]
            if remaining <= segmentLength || index == segmentLengths.count - 1 {
                let fraction = segmentLength > 0 ? min(1, remaining / segmentLength) : 0
                let start = polyline[index]
                let end = polyline[index + 1]
                return RouteCoordinate(
                    latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                    longitude: start.longitude + (end.longitude - start.longitude) * fraction
                )
            }
            remaining -= segmentLength
        }

        return polyline[polyline.count - 1]
    }

    private static func parseDurationSeconds(_ raw: String?) -> TimeInterval? {
        guard let raw, raw.hasSuffix("s") else { return nil }
        let number = raw.dropLast()
        guard let seconds = Double(number) else { return nil }
        return seconds
    }

    static func findMatchingRoute(routes: [ParsedTransitRoute], busNumber: String) -> ParsedTransitRoute? {
        routes.first { route in
            route.steps.contains { step in
                isBusStep(step) && stepMatchesBusNumber(step, busNumber: busNumber)
            }
        }
    }

    private static func isBusStep(_ step: ParsedTransitStep) -> Bool {
        step.travelMode == "TRANSIT" && step.vehicleType == "BUS"
    }

    static func stepMatchesBusNumber(_ step: ParsedTransitStep, busNumber: String) -> Bool {
        let candidates = [
            step.lineName,
            step.lineNameShort,
            step.headsign,
            step.vehicleName,
        ]

        return busNumberVariants(busNumber).contains { variant in
            candidates.contains { text in
                guard let text else { return false }
                return containsBusNumber(text, busNumber: variant)
            }
        }
    }

    static func busNumberVariants(_ busNumber: String) -> [String] {
        let normalized = busNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return [] }

        var variants = Set([normalized])

        if let regex = try? NSRegularExpression(pattern: #"^([A-Z]*?)0+([1-9]\d*)([A-Z]*)$"#),
           let match = regex.firstMatch(
               in: normalized,
               range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
           ),
           let prefixRange = Range(match.range(at: 1), in: normalized),
           let numberRange = Range(match.range(at: 2), in: normalized),
           let suffixRange = Range(match.range(at: 3), in: normalized) {
            let compact = String(normalized[prefixRange]) + String(normalized[numberRange]) + String(normalized[suffixRange])
            variants.insert(compact)
        }

        return Array(variants)
    }

    static func containsBusNumber(_ text: String, busNumber: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedBusNumber = busNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedText.isEmpty, !trimmedBusNumber.isEmpty else { return false }
        if trimmedText == trimmedBusNumber { return true }

        let pattern = #"(?<![0-9A-Z])"# + NSRegularExpression.escapedPattern(for: trimmedBusNumber) + #"(?![0-9A-Z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
        return regex.firstMatch(in: trimmedText, range: range) != nil
    }

    private static func alightStopText(for route: ParsedTransitRoute, busNumber: String) -> String {
        guard let step = route.steps.first(where: { isBusStep($0) && stepMatchesBusNumber($0, busNumber: busNumber) }) else {
            return AppLocaleString.currentText("osmBus_降車バス停不明")
        }

        if let stopName = step.arrivalStopName, !stopName.isEmpty {
            if let stopCount = step.stopCount, stopCount > 0 {
                return AppLocaleString.currentFormatted("osmBus_降車_%@_%d停", stopName, stopCount)
            }
            return AppLocaleString.currentFormatted("osmBus_降車_%@", stopName)
        }

        if let stopCount = step.stopCount, stopCount > 0 {
            return AppLocaleString.currentFormatted("osmBus_停分乗車_%d", stopCount)
        }

        return AppLocaleString.currentText("osmBus_降車_目的地方面")
    }

    private static func formatArrivalTime(after durationSeconds: TimeInterval) -> String {
        let arrival = Date().addingTimeInterval(durationSeconds)
        let formatter = DateFormatter()
        formatter.locale = AppLocaleString.currentLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }

    private static func appLanguageCode(for regionCode: String) -> String {
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
