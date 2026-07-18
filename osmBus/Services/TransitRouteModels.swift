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
    let polylineCoordinates: [RouteCoordinate]
    let departureStopLocation: RouteCoordinate?
    let arrivalStopLocation: RouteCoordinate?
}

struct ParsedTransitRoute: Sendable {
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
