import Foundation

extension GoogleRoutesAPIService {
    static func displayDuration(for route: ParsedTransitRoute, locale: Locale) -> String {
        if let durationText = route.durationText, !durationText.isEmpty {
            return durationText
        }
        let minutes = max(1, Int((route.durationSeconds / 60.0).rounded()))
        return AppLocaleString.formatted("所要時間_%d分", locale: locale, minutes)
    }

    static func displayFare(for route: ParsedTransitRoute) -> String? {
        guard let fareText = route.fareText, !fareText.isEmpty else { return nil }
        return fareText
    }

    static func transitBusLineLabels(for route: ParsedTransitRoute) -> [String] {
        route.steps.compactMap { step in
            guard isBusStep(step) else { return nil }
            return transitStepDisplayLabel(for: step)
        }
    }

    static func transitBusLineBadgeLabels(for route: ParsedTransitRoute) -> [String] {
        route.steps.compactMap { step in
            guard isBusStep(step) else { return nil }
            return compactTransitBusLineBadgeLabel(for: step)
        }
    }

    static func transitOtherTransitLineLabels(for route: ParsedTransitRoute) -> [String] {
        route.steps.compactMap { step in
            guard step.travelMode == "TRANSIT", !isBusStep(step) else { return nil }
            return transitStepDisplayLabel(for: step)
        }
    }

    static func transitLineSummary(for route: ParsedTransitRoute) -> String {
        let lines = route.steps.compactMap { step -> String? in
            guard step.travelMode == "TRANSIT" else { return nil }
            return transitStepDisplayLabel(for: step)
        }
        if lines.isEmpty {
            return AppLocaleString.currentText("公共交通ステップなし")
        }
        return lines.joined(separator: " → ")
    }

    static func transitStepDisplayLabel(for step: ParsedTransitStep) -> String? {
        if let short = step.lineNameShort, !short.isEmpty { return short }
        if let name = step.lineName, !name.isEmpty { return name }
        if let headsign = step.headsign, !headsign.isEmpty { return headsign }
        if let vehicle = step.vehicleName, !vehicle.isEmpty { return vehicle }
        if let vehicleType = step.vehicleType, !vehicleType.isEmpty { return vehicleType }
        return nil
    }

    static func compactTransitBusLineBadgeLabel(for step: ParsedTransitStep) -> String {
        let sources = [step.lineNameShort, step.lineName, step.headsign, step.vehicleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for source in sources {
            if source.count <= 10, !source.contains(" ") {
                return source
            }
            if let token = preferredBusToken(from: source) {
                return token
            }
        }

        if let fallback = sources.first {
            return preferredBusToken(from: fallback) ?? fallback
        }

        return AppLocaleString.currentText("バス")
    }

    static func preferredBusToken(from text: String) -> String? {
        let tokens = extractBusTokens(from: text)
        guard !tokens.isEmpty else { return nil }

        if let rich = tokens.first(where: { !$0.prefix.isEmpty || !$0.suffix.isEmpty }) {
            return rich.displayToken
        }
        return tokens.first?.displayToken
    }

    static func routeDirectionBadge(for route: ParsedTransitRoute, locale: Locale) -> String? {
        guard let step = route.steps.first(where: { isBusStep($0) }),
              let bearing = stepBearing(from: step) else { return nil }
        let dirText = AppLocaleString.text(compassDirectionKeys[Int((bearing + 22.5) / 45) % 8], locale: locale)
        return AppLocaleString.formatted("方向バッジ_%@", locale: locale, dirText)
    }
}
