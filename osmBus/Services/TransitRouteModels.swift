import Foundation

struct RouteCoordinate: Sendable, Hashable, Codable {
    let latitude: Double
    let longitude: Double
}

struct ParsedTransitStep: Sendable, Codable {
    let travelMode: String
    let lineName: String?
    let lineNameShort: String?
    let headsign: String?
    let vehicleType: String?
    let vehicleName: String?
    let departureStopName: String?
    let arrivalStopName: String?
    let polylineCoordinates: [RouteCoordinate]
    let departureStopLocation: RouteCoordinate?
    let arrivalStopLocation: RouteCoordinate?
}

struct ParsedTransitRoute: Sendable, Codable {
    let durationSeconds: TimeInterval
    let durationText: String?
    let fareText: String?
    let fareAmount: Double?
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

struct BusCheckResponse: Sendable {
    let outcome: BusCheckOutcome
    let matchingRouteIndex: Int?
    let matchingRoute: ParsedTransitRoute?
    let boardingDirectionHint: String?
    let isBoardingRouteCheapest: Bool
}

/// 目的地ごとの経路蓄積。ユーザーが初期化するまで残し、同じ行き先に戻ったときは再検索せず使う。
struct TripRouteRecord: Codable {
    var routes: [ParsedTransitRoute]
    var alternateRoutes: [String: ParsedTransitRoute]
    var alternateSearchDone: [String]
    var updatedAt: Date
    var destination: Destination?
}

struct SavedRouteTrip: Identifiable {
    let id: String
    let destination: Destination
    let routes: [ParsedTransitRoute]
    let updatedAt: Date

    var routeCount: Int { routes.count }

    func linePreview(separator: String = "、", maxLines: Int = 3) -> String {
        let labels = routes.prefix(maxLines).map {
            GoogleRoutesAPIService.transitBusLineBadgeLabels(for: $0).joined(separator: "→")
        }
        .filter { !$0.isEmpty }
        if routes.count > maxLines {
            return labels.joined(separator: separator) + "…"
        }
        return labels.joined(separator: separator)
    }
}

enum TransitRouteArchive {
    private static let maxDestinations = 20
    private static let fileName = "transit-route-archive.json"

    static func listedTrips(from archive: [String: TripRouteRecord]? = nil) -> [SavedRouteTrip] {
        let source = archive ?? load()
        return source.compactMap { key, record -> SavedRouteTrip? in
            guard !record.routes.isEmpty else { return nil }
            guard let destination = record.destination ?? destination(fromArchiveKey: key) else {
                return nil
            }
            return SavedRouteTrip(
                id: key,
                destination: destination,
                routes: record.routes,
                updatedAt: record.updatedAt
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func destination(fromArchiveKey key: String) -> Destination? {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              let longitude = Double(parts[parts.count - 1]),
              let latitude = Double(parts[parts.count - 2]) else { return nil }
        let name = parts.dropLast(2).joined(separator: "|")
        guard !name.isEmpty else { return nil }
        return Destination(name: name, subtitle: nil, latitude: latitude, longitude: longitude)
    }

    static func load() -> [String: TripRouteRecord] {
        guard let data = try? Data(contentsOf: fileURL()) else { return [:] }
        return (try? JSONDecoder().decode([String: TripRouteRecord].self, from: data)) ?? [:]
    }

    static func save(_ archive: [String: TripRouteRecord]) {
        var trimmed = archive
        if trimmed.count > maxDestinations {
            let drop = trimmed.count - maxDestinations
            let oldestKeys = trimmed
                .sorted { $0.value.updatedAt < $1.value.updatedAt }
                .prefix(drop)
                .map(\.key)
            for key in oldestKeys {
                trimmed.removeValue(forKey: key)
            }
        }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? data.write(to: fileURL(), options: [.atomic])
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL())
    }

    private static func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("osmBus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}
