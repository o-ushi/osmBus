import CoreLocation
import Foundation

extension GoogleRoutesAPIService {
    /// Google の行き先案に入力番号が無くても、乗換停留所まで同じ方向に走るバスなら乗車可とする。
    /// 番号表の蓄積データベースには混ぜない。見つかった経路は matchingRoute にだけ載せる。
    static func evaluateAlternateTransferBoarding(
        busNumber: String,
        destinationRoutes: [ParsedTransitRoute],
        originLatitude: Double,
        originLongitude: Double,
        apiKey: String
    ) async -> BusCheckResponse? {
        let hubs = uniqueTransferHubs(in: destinationRoutes)
        guard !hubs.isEmpty else { return nil }

        if let googleMatch = await matchViaGoogleHubRoutes(
            busNumber: busNumber,
            hubs: hubs,
            destinationRoutes: destinationRoutes,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            apiKey: apiKey
        ) {
            return googleMatch
        }

        return await matchViaOSMRoute(
            busNumber: busNumber,
            hubs: hubs,
            destinationRoutes: destinationRoutes,
            originLatitude: originLatitude,
            originLongitude: originLongitude
        )
    }

    struct TransferHub {
        let parentRouteIndex: Int
        let firstBusStepIndex: Int
        let stopName: String
        let location: RouteCoordinate
    }

    static func uniqueTransferHubs(in routes: [ParsedTransitRoute]) -> [TransferHub] {
        var seen = Set<String>()
        var hubs: [TransferHub] = []

        for (routeIndex, route) in routes.enumerated() {
            guard let firstBusIdx = route.steps.firstIndex(where: { isBusStep($0) }) else { continue }
            let laterTransit = route.steps[(firstBusIdx + 1)...].contains { $0.travelMode == "TRANSIT" }
            guard laterTransit else { continue }

            let step = route.steps[firstBusIdx]
            guard let location = step.arrivalStopLocation else { continue }
            let key = hubKey(location)
            guard seen.insert(key).inserted else { continue }

            let name = step.arrivalStopName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            hubs.append(
                TransferHub(
                    parentRouteIndex: routeIndex,
                    firstBusStepIndex: firstBusIdx,
                    stopName: name,
                    location: location
                )
            )
            if hubs.count >= 3 { break }
        }
        return hubs
    }

    private static func hubKey(_ location: RouteCoordinate) -> String {
        let lat = (location.latitude * 1000).rounded() / 1000
        let lon = (location.longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }

    private static func matchViaGoogleHubRoutes(
        busNumber: String,
        hubs: [TransferHub],
        destinationRoutes: [ParsedTransitRoute],
        originLatitude: Double,
        originLongitude: Double,
        apiKey: String
    ) async -> BusCheckResponse? {
        await withTaskGroup(of: (TransferHub, [ParsedTransitRoute])?.self) { group in
            for hub in hubs {
                group.addTask {
                    let result = await fetchTransitRoutes(
                        originLatitude: originLatitude,
                        originLongitude: originLongitude,
                        destinationLatitude: hub.location.latitude,
                        destinationLongitude: hub.location.longitude,
                        apiKey: apiKey
                    )
                    guard case .success(let routes) = result, !routes.isEmpty else { return nil }
                    return (hub, routes)
                }
            }

            var best: BusCheckResponse?
            for await item in group {
                guard let (hub, routes) = item else { continue }
                let response = evaluateBusQuery(busNumber, routes: routes)
                switch response.outcome {
                case .doNotBoard, .noTransitRoutes, .configurationError, .apiError:
                    continue
                case .boardAll, .boardIfVariant:
                    break
                }
                guard let matchRoute = response.matchingRoute else { continue }
                let resolvedNumber = discoverBusCandidates(in: [matchRoute], numericQuery: busNumber).first
                    ?? primaryBusLineRef(route: matchRoute, busNumber: busNumber)
                    ?? busNumber
                guard let replacement = boardingBusStep(route: matchRoute, busNumber: resolvedNumber),
                      isFirstBusOnRoute(matchRoute, busNumber: resolvedNumber) else { continue }

                let parent = destinationRoutes[hub.parentRouteIndex]
                let stitched = replacingBusStep(
                    in: parent,
                    at: hub.firstBusStepIndex,
                    with: replacement
                )
                best = boardingResponse(
                    outcome: alternateOutcome(for: resolvedNumber, route: stitched, variantNames: variantNames(from: response)),
                    match: (hub.parentRouteIndex, stitched),
                    busNumber: resolvedNumber,
                    allRoutes: destinationRoutes,
                    directionHintOverride: alternateHint(hubName: hub.stopName, route: stitched, busNumber: resolvedNumber)
                )
                group.cancelAll()
                break
            }
            return best
        }
    }

    private static func isFirstBusOnRoute(_ route: ParsedTransitRoute, busNumber: String) -> Bool {
        guard let firstIdx = route.steps.firstIndex(where: { isBusStep($0) }) else { return false }
        return stepMatchesBusNumber(route.steps[firstIdx], busNumber: busNumber)
    }

    private static func variantNames(from response: BusCheckResponse) -> [String]? {
        if case .boardIfVariant(let names, _, _) = response.outcome {
            return names
        }
        return nil
    }

    private static func matchViaOSMRoute(
        busNumber: String,
        hubs: [TransferHub],
        destinationRoutes: [ParsedTransitRoute],
        originLatitude: Double,
        originLongitude: Double
    ) async -> BusCheckResponse? {
        guard ThirdPartyDataConsent.isGranted else { return nil }

        let origin = CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude)
        let candidates: [BusRouteCandidate]
        do {
            candidates = Array(
                try await OverpassAPIService.searchCandidates(ref: busNumber, near: origin, radiusMeters: 8_000)
                    .prefix(6)
            )
        } catch {
            return nil
        }
        guard !candidates.isEmpty else { return nil }

        var matched: [(ref: String, hub: TransferHub, step: ParsedTransitStep)] = []

        for candidate in candidates {
            let detail: BusRouteDetail
            do {
                detail = try await OverpassAPIService.fetchRouteDetail(candidate)
            } catch {
                continue
            }
            guard let hit = osmStepTowardHub(detail: detail, origin: origin, hubs: hubs) else { continue }
            matched.append((candidate.ref, hit.hub, hit.step))
        }

        guard let first = matched.first else { return nil }
        let refs = Array(Set(matched.map(\.ref))).sorted()
        let parent = destinationRoutes[first.hub.parentRouteIndex]
        let stitched = replacingBusStep(
            in: parent,
            at: first.hub.firstBusStepIndex,
            with: first.step
        )
        let primaryRef = refs.contains(where: { $0.caseInsensitiveCompare(busNumber) == .orderedSame })
            ? busNumber
            : (refs.first ?? first.ref)

        return boardingResponse(
            outcome: alternateOutcome(for: primaryRef, route: stitched, variantNames: refs.count > 1 ? refs : nil),
            match: (first.hub.parentRouteIndex, stitched),
            busNumber: primaryRef,
            allRoutes: destinationRoutes,
            directionHintOverride: alternateHint(hubName: first.hub.stopName, route: stitched, busNumber: primaryRef)
        )
    }

    private static func osmStepTowardHub(
        detail: BusRouteDetail,
        origin: CLLocationCoordinate2D,
        hubs: [TransferHub]
    ) -> (hub: TransferHub, step: ParsedTransitStep)? {
        let stops = detail.stops
        guard stops.count >= 2 else { return nil }

        let originWalkMeters: Double = 700
        let hubMeters: Double = 280

        guard let originIdx = nearestStopIndex(in: stops, to: origin, maxMeters: originWalkMeters) else {
            return nil
        }

        for hub in hubs {
            let hubCoord = CLLocationCoordinate2D(latitude: hub.location.latitude, longitude: hub.location.longitude)
            guard let hubIdx = nearestStopIndex(in: stops, to: hubCoord, maxMeters: hubMeters),
                  originIdx < hubIdx else { continue }

            let coords = polyline(from: detail, start: stops[originIdx].coordinate, end: stops[hubIdx].coordinate)
            let step = ParsedTransitStep(
                travelMode: "TRANSIT",
                lineName: detail.candidate.ref,
                lineNameShort: detail.candidate.ref,
                headsign: detail.candidate.to,
                vehicleType: "BUS",
                vehicleName: detail.candidate.ref,
                departureStopName: stops[originIdx].name,
                arrivalStopName: hub.stopName.isEmpty ? stops[hubIdx].name : hub.stopName,
                polylineCoordinates: coords,
                departureStopLocation: RouteCoordinate(
                    latitude: stops[originIdx].coordinate.latitude,
                    longitude: stops[originIdx].coordinate.longitude
                ),
                arrivalStopLocation: hub.location
            )
            return (hub, step)
        }
        return nil
    }

    private static func nearestStopIndex(
        in stops: [BusStop],
        to coordinate: CLLocationCoordinate2D,
        maxMeters: Double
    ) -> Int? {
        var best: (Int, Double)?
        for (index, stop) in stops.enumerated() {
            let meters = distanceMeters(
                fromLatitude: coordinate.latitude,
                fromLongitude: coordinate.longitude,
                toLatitude: stop.coordinate.latitude,
                toLongitude: stop.coordinate.longitude
            )
            if meters <= maxMeters, best == nil || meters < best!.1 {
                best = (index, meters)
            }
        }
        return best?.0
    }

    private static func polyline(
        from detail: BusRouteDetail,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> [RouteCoordinate] {
        let flat = detail.polylineSegments.flatMap { $0 }
        guard flat.count >= 2 else {
            return [
                RouteCoordinate(latitude: start.latitude, longitude: start.longitude),
                RouteCoordinate(latitude: end.latitude, longitude: end.longitude),
            ]
        }

        func nearestIndex(to target: CLLocationCoordinate2D) -> Int {
            var best = 0
            var bestMeters = Double.greatestFiniteMagnitude
            for (index, coord) in flat.enumerated() {
                let meters = distanceMeters(
                    fromLatitude: target.latitude,
                    fromLongitude: target.longitude,
                    toLatitude: coord.latitude,
                    toLongitude: coord.longitude
                )
                if meters < bestMeters {
                    bestMeters = meters
                    best = index
                }
            }
            return best
        }

        var fromIdx = nearestIndex(to: start)
        var toIdx = nearestIndex(to: end)
        if fromIdx > toIdx { swap(&fromIdx, &toIdx) }
        let slice = flat[fromIdx...toIdx]
        return slice.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }

    static func replacingBusStep(
        in parent: ParsedTransitRoute,
        at index: Int,
        with step: ParsedTransitStep
    ) -> ParsedTransitRoute {
        var steps = parent.steps
        guard index >= 0, index < steps.count else { return parent }
        steps[index] = step
        return ParsedTransitRoute(
            durationSeconds: parent.durationSeconds,
            durationText: parent.durationText,
            fareText: parent.fareText,
            fareAmount: parent.fareAmount,
            steps: steps
        )
    }

    private static func alternateOutcome(
        for busNumber: String,
        route: ParsedTransitRoute,
        variantNames: [String]?
    ) -> BusCheckOutcome {
        let arrival = AppLocaleString.currentFormatted(
            "到着予定_%@",
            formatArrivalTime(after: route.durationSeconds)
        )
        let alight = alightStopText(for: route, busNumber: busNumber)
        if let names = variantNames, names.count > 1 {
            return .boardIfVariant(names: names, arrivalText: arrival, alightStopText: alight)
        }
        return .boardAll(arrivalText: arrival, alightStopText: alight)
    }

    private static func alternateHint(
        hubName: String,
        route: ParsedTransitRoute,
        busNumber: String
    ) -> String {
        let transfer = hubName.isEmpty
            ? AppLocaleString.currentText("代替乗車_乗換まで")
            : AppLocaleString.currentFormatted("代替乗車_乗換_%@", hubName)
        if let compass = localizedDirectionHint(for: route, busNumber: busNumber),
           compass == AppLocaleString.currentText("方向ヒント_どちらでも") {
            return "\(transfer) · \(compass)"
        }
        return transfer
    }

    static func boardingResponse(
        outcome: BusCheckOutcome,
        match: (index: Int, route: ParsedTransitRoute),
        busNumber: String,
        allRoutes: [ParsedTransitRoute],
        directionHintOverride: String?
    ) -> BusCheckResponse {
        var response = boardingResponse(outcome: outcome, match: match, busNumber: busNumber, allRoutes: allRoutes)
        if let directionHintOverride {
            response = BusCheckResponse(
                outcome: response.outcome,
                matchingRouteIndex: response.matchingRouteIndex,
                matchingRoute: response.matchingRoute,
                boardingDirectionHint: directionHintOverride,
                isBoardingRouteCheapest: response.isBoardingRouteCheapest
            )
        }
        return response
    }
}
