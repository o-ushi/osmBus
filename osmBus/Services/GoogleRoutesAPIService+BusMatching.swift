import Foundation

extension GoogleRoutesAPIService {
    static func evaluateBusQuery(_ query: String, routes: [ParsedTransitRoute]) -> BusCheckResponse {
        if query.allSatisfy(\.isNumber) {
            return evaluateNumericBusQuery(query, routes: routes)
        }

        if let match = findMatchingRouteWithIndex(routes: routes, busNumber: query) {
            return boardingResponse(outcome: boardOutcome(for: query, route: match.route), match: match, busNumber: query, allRoutes: routes)
        }
        return BusCheckResponse(outcome: .doNotBoard, matchingRouteIndex: nil, matchingRoute: nil, boardingDirectionHint: nil, isBoardingRouteCheapest: true)
    }

    static func evaluateNumericBusQuery(
        _ numericQuery: String,
        routes: [ParsedTransitRoute]
    ) -> BusCheckResponse {
        let candidates = discoverBusCandidates(in: routes, numericQuery: numericQuery)

        if candidates.isEmpty {
            if let match = findMatchingRouteWithIndex(routes: routes, busNumber: numericQuery) {
                return boardingResponse(outcome: boardOutcome(for: numericQuery, route: match.route), match: match, busNumber: numericQuery, allRoutes: routes)
            }
            return BusCheckResponse(outcome: .doNotBoard, matchingRouteIndex: nil, matchingRoute: nil, boardingDirectionHint: nil, isBoardingRouteCheapest: true)
        }

        let workingVariants = candidates.filter { findMatchingRoute(routes: routes, busNumber: $0) != nil }
        guard !workingVariants.isEmpty,
              let primary = workingVariants.first,
              let match = findMatchingRouteWithIndex(routes: routes, busNumber: primary) else {
            return BusCheckResponse(outcome: .doNotBoard, matchingRouteIndex: nil, matchingRoute: nil, boardingDirectionHint: nil, isBoardingRouteCheapest: true)
        }
        return boardingResponse(outcome: variantOutcome(for: workingVariants, route: match.route), match: match, busNumber: primary, allRoutes: routes)
    }

    static func boardingResponse(
        outcome: BusCheckOutcome,
        match: (index: Int, route: ParsedTransitRoute),
        busNumber: String,
        allRoutes: [ParsedTransitRoute]
    ) -> BusCheckResponse {
        // 同じバス番号にヒットする全ルートの中の最安運賃で比較する。
        // 例: 35 → 候補3(35A→E07, ¥250) と 候補5(35A, ¥180) が両方ヒットする場合、
        //     最安の ¥180 を基準にすることで正しく最安値判定できる。
        let bestMatchingFare = allRoutes
            .filter { findMatchingRoute(routes: [$0], busNumber: busNumber) != nil }
            .compactMap { $0.fareAmount }
            .min()
        let isCheapest: Bool
        if let fare = bestMatchingFare {
            isCheapest = !allRoutes.contains { ($0.fareAmount ?? .infinity) < fare }
        } else {
            isCheapest = true
        }
        return BusCheckResponse(
            outcome: outcome,
            matchingRouteIndex: match.index,
            matchingRoute: match.route,
            boardingDirectionHint: localizedDirectionHint(for: match.route, busNumber: busNumber),
            isBoardingRouteCheapest: isCheapest
        )
    }

    static func boardOutcome(for busNumber: String, route: ParsedTransitRoute) -> BusCheckOutcome {
        .boardAll(
            arrivalText: AppLocaleString.currentFormatted(
                "到着予定_%@",
                formatArrivalTime(after: route.durationSeconds)
            ),
            alightStopText: alightStopText(for: route, busNumber: busNumber)
        )
    }

    static func variantOutcome(
        for names: [String],
        route: ParsedTransitRoute
    ) -> BusCheckOutcome {
        guard let primary = names.first else { return .doNotBoard }
        return .boardIfVariant(
            names: names,
            arrivalText: AppLocaleString.currentFormatted(
                "到着予定_%@",
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

    static func extractBusTokens(from text: String) -> [BusIdentifierParts] {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else { return [] }

        // プレフィックスは "BRT" のような3文字の系統もあるため {0,3} まで許容する
        // (以前は {0,2} だったため "BRT01" が "RT01" に誤抽出されていた)。
        guard let regex = try? NSRegularExpression(pattern: #"([A-Z]{0,3}\d{1,4}[A-Z]{0,3})"#) else {
            return []
        }

        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        return regex.matches(in: normalized, range: range).compactMap { match in
            guard let tokenRange = Range(match.range(at: 1), in: normalized) else { return nil }
            return parseBusIdentifierParts(String(normalized[tokenRange]))
        }
    }

    struct BusIdentifierParts {
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

    static func parseBusIdentifierParts(_ raw: String) -> BusIdentifierParts? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let regex = try? NSRegularExpression(pattern: #"^([A-Z]{0,3})(\d{1,4})([A-Z]{0,3})$"#),
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

    static func sortBusTokens(_ tokens: [String]) -> [String] {
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

    static func findMatchingRoute(routes: [ParsedTransitRoute], busNumber: String) -> ParsedTransitRoute? {
        findMatchingRouteWithIndex(routes: routes, busNumber: busNumber)?.route
    }

    /// 同じバス番号が複数の経路案(itinerary)にヒットすることがある(例: 直行案と、
    /// 途中で同じ番号のバスに乗ってから別路線に乗り換える案が両方 Google から返る)。
    /// 単純に配列の先頭一致を採用すると、乗り換え不要のはずのバスなのに乗り換え案の
    /// 「乗り換え停留所」が降車地点として設定され、見当違いの場所で到着アラートが
    /// 鳴る不具合が起きる。ヒットしたバス区間の後にさらに TRANSIT 区間が続かない
    /// (＝乗り換え不要で目的地に着く)経路を優先する。
    static func findMatchingRouteWithIndex(
        routes: [ParsedTransitRoute],
        busNumber: String
    ) -> (index: Int, route: ParsedTransitRoute)? {
        var fallback: (index: Int, route: ParsedTransitRoute)?

        for (index, route) in routes.enumerated() {
            guard let stepIdx = route.steps.firstIndex(where: { step in
                isBusStep(step) && stepMatchesBusNumber(step, busNumber: busNumber)
            }) else { continue }

            if fallback == nil {
                fallback = (index, route)
            }

            let requiresTransferAfter = route.steps[(stepIdx + 1)...].contains { $0.travelMode == "TRANSIT" }
            if !requiresTransferAfter {
                return (index, route)
            }
        }

        return fallback
    }

    static func boardingBusStep(route: ParsedTransitRoute, busNumber: String) -> ParsedTransitStep? {
        route.steps.first(where: { isBusStep($0) && stepMatchesBusNumber($0, busNumber: busNumber) })
            ?? route.steps.first(where: { isBusStep($0) })
    }

    static func primaryBusLineRef(route: ParsedTransitRoute, busNumber: String) -> String? {
        guard let step = boardingBusStep(route: route, busNumber: busNumber) else { return nil }
        return compactTransitBusLineBadgeLabel(for: step)
    }

    static func isBusStep(_ step: ParsedTransitStep) -> Bool {
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

    static func alightStopText(for route: ParsedTransitRoute, busNumber: String) -> String {
        guard let step = route.steps.first(where: { isBusStep($0) && stepMatchesBusNumber($0, busNumber: busNumber) }) else {
            return AppLocaleString.currentText("降車バス停不明")
        }

        if let stopName = step.arrivalStopName, !stopName.isEmpty {
            return AppLocaleString.currentFormatted("降車_%@", stopName)
        }

        return AppLocaleString.currentText("降車_目的地方面")
    }

    /// 入力文字列に合致するバス路線候補ラベルを返す。
    /// 数字のみ入力の場合は discoverBusCandidates を使い E05・K05 など
    /// 前頭アルファベット付きのバスも自動的に候補に含める。
    static func busLineCandidates(for input: String, in routes: [ParsedTransitRoute]) -> [String] {
        guard !input.isEmpty else { return [input] }

        if input.allSatisfy(\.isNumber) {
            let found = discoverBusCandidates(in: routes, numericQuery: input)
            if !found.isEmpty { return found }
        }

        // アルファベット含む入力 or 数字のみで候補なし → stepMatchesBusNumber ベース
        var seen = Set<String>()
        var result: [String] = []
        for route in routes {
            for step in route.steps where isBusStep(step) {
                guard stepMatchesBusNumber(step, busNumber: input) else { continue }
                let label = compactTransitBusLineBadgeLabel(for: step)
                if seen.insert(label).inserted { result.append(label) }
            }
        }
        return result.isEmpty ? [input] : result.sorted()
    }

    static let compassDirectionKeys = [
        "方向_N", "方向_NE", "方向_E", "方向_SE",
        "方向_S", "方向_SW", "方向_W", "方向_NW",
    ]

    // バスステップの走行方向（方位角）を返す。ポリラインか乗降停留所座標から計算。
    static func stepBearing(from step: ParsedTransitStep) -> Double? {
        let coords = step.polylineCoordinates
        if coords.count >= 2 {
            let endIdx = min(coords.count - 1, max(1, coords.count / 5))
            return compassBearing(from: coords[0], to: coords[endIdx])
        }
        if let dep = step.departureStopLocation, let arr = step.arrivalStopLocation {
            return compassBearing(from: dep, to: arr)
        }
        return nil
    }

    static func localizedDirectionHint(for route: ParsedTransitRoute, busNumber: String) -> String? {
        guard let step = route.steps.first(where: { isBusStep($0) && stepMatchesBusNumber($0, busNumber: busNumber) }),
              let bearing = stepBearing(from: step) else { return nil }
        let dirText = AppLocaleString.currentText(compassDirectionKeys[Int((bearing + 22.5) / 45) % 8])
        return AppLocaleString.currentFormatted("方向ヒント_%@", dirText)
    }

    static func formatArrivalTime(after durationSeconds: TimeInterval) -> String {
        let arrival = Date().addingTimeInterval(durationSeconds)
        let formatter = DateFormatter()
        formatter.locale = AppLocaleString.currentLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }
}
