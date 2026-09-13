import CoreLocation
import Foundation

extension GoogleRoutesAPIService {
    /// Google 案に入力番号が無くても、溜めた全線または追加検索で乗れるなら乗車可とする。
    /// 乗換の有無は問わない。目的地まで同じ路線なら直通としてナビに使う。
    static func evaluateAlternateTransferBoarding(
        busNumber: String,
        destinationRoutes: [ParsedTransitRoute],
        originLatitude: Double,
        originLongitude: Double,
        destinationLatitude: Double,
        destinationLongitude: Double,
        destinationName: String?,
        apiKey _: String
    ) async -> BusCheckResponse? {
        let hubs = alternateAlightTargets(
            in: destinationRoutes,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
            destinationName: destinationName
        )
        guard !hubs.isEmpty else { return nil }

        if let stored = matchViaStoredLineMaps(
            busNumber: busNumber,
            hubs: hubs,
            destinationRoutes: destinationRoutes,
            originLatitude: originLatitude,
            originLongitude: originLongitude
        ) {
            return stored
        }

        // 向かってくるバスを判定するので、Google の乗換再検索は待たない。
        // 手元に無い初回だけ OSM 全線を短時間で取り、溜めて次から即判定する。
        return await matchViaOSMRoute(
            busNumber: busNumber,
            hubs: hubs,
            destinationRoutes: destinationRoutes,
            originLatitude: originLatitude,
            originLongitude: originLongitude
        )
    }

    struct TransferHub {
        enum Kind {
            case transfer
            case destination
        }

        let parentRouteIndex: Int
        let firstBusStepIndex: Int
        let stopName: String
        let location: RouteCoordinate
        let kind: Kind
        let matchRadiusMeters: Double
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
                    location: location,
                    kind: .transfer,
                    matchRadiusMeters: 280
                )
            )
            if hubs.count >= 3 { break }
        }
        return hubs
    }

    static func alternateAlightTargets(
        in routes: [ParsedTransitRoute],
        destinationLatitude: Double,
        destinationLongitude: Double,
        destinationName: String?
    ) -> [TransferHub] {
        var hubs = uniqueTransferHubs(in: routes)
        let destLocation = RouteCoordinate(latitude: destinationLatitude, longitude: destinationLongitude)
        let destKey = hubKey(destLocation)
        if !hubs.contains(where: { hubKey($0.location) == destKey }) {
            let parentIndex = routes.enumerated().min(by: { $0.element.durationSeconds < $1.element.durationSeconds })?.offset ?? 0
            let firstBusIdx = routes.indices.contains(parentIndex)
                ? (routes[parentIndex].steps.firstIndex(where: { isBusStep($0) }) ?? 0)
                : 0
            let name = destinationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            hubs.insert(
                TransferHub(
                    parentRouteIndex: parentIndex,
                    firstBusStepIndex: firstBusIdx,
                    stopName: name,
                    location: destLocation,
                    kind: .destination,
                    matchRadiusMeters: 550
                ),
                at: 0
            )
        }
        return hubs
    }

    private static func hubKey(_ location: RouteCoordinate) -> String {
        let lat = (location.latitude * 1000).rounded() / 1000
        let lon = (location.longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }

    /// 溜め込んだ全線から、今の出発地と目的地（または乗換停）が同じ路線上なら乗車可。
    static func matchViaStoredLineMaps(
        busNumber: String,
        hubs: [TransferHub]? = nil,
        destinationRoutes: [ParsedTransitRoute],
        originLatitude: Double,
        originLongitude: Double,
        destinationLatitude: Double? = nil,
        destinationLongitude: Double? = nil,
        destinationName: String? = nil
    ) -> BusCheckResponse? {
        let resolvedHubs: [TransferHub]
        if let hubs, !hubs.isEmpty {
            resolvedHubs = hubs
        } else if let destinationLatitude, let destinationLongitude {
            resolvedHubs = alternateAlightTargets(
                in: destinationRoutes,
                destinationLatitude: destinationLatitude,
                destinationLongitude: destinationLongitude,
                destinationName: destinationName
            )
        } else {
            resolvedHubs = uniqueTransferHubs(in: destinationRoutes)
        }
        guard !resolvedHubs.isEmpty else { return nil }
        let origin = CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude)
        let details = BusLineMapStore.details(matching: busNumber)
        guard !details.isEmpty else { return nil }

        var matched: [(detail: BusRouteDetail, hub: TransferHub, step: ParsedTransitStep)] = []
        for detail in details {
            guard let hit = osmStepTowardHub(detail: detail, origin: origin, hubs: resolvedHubs) else { continue }
            matched.append((detail, hit.hub, hit.step))
        }
        guard let first = matched.first else { return nil }
        BusLineMapStore.touch(relationId: first.detail.candidate.id)

        let refs = Array(Set(matched.map(\.detail.candidate.ref))).sorted()
        let primaryRef = refs.contains(where: { $0.caseInsensitiveCompare(busNumber) == .orderedSame })
            ? busNumber
            : (refs.first ?? first.detail.candidate.ref)
        let route = navigationRoute(
            for: first.hub,
            step: first.step,
            parent: destinationRoutes[first.hub.parentRouteIndex]
        )

        return boardingResponse(
            outcome: alternateOutcome(for: primaryRef, route: route, variantNames: refs.count > 1 ? refs : nil),
            match: (first.hub.parentRouteIndex, route),
            busNumber: primaryRef,
            allRoutes: destinationRoutes,
            directionHintOverride: alternateHint(hubName: first.hub.stopName, route: route, busNumber: primaryRef)
        )
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
                try await OverpassAPIService.searchCandidates(
                    ref: busNumber,
                    near: origin,
                    radiusMeters: 8_000,
                    timeoutSeconds: 8,
                    maxEndpoints: 1
                )
                .prefix(4)
            )
        } catch {
            return nil
        }
        guard !candidates.isEmpty else { return nil }

        return await withTaskGroup(
            of: (BusRouteDetail, TransferHub, ParsedTransitStep)?.self
        ) { group in
            for candidate in candidates {
                group.addTask {
                    let detail: BusRouteDetail
                    do {
                        detail = try await OverpassAPIService.fetchRouteDetail(
                            candidate,
                            timeoutSeconds: 10,
                            maxEndpoints: 1
                        )
                    } catch {
                        return nil
                    }
                    BusLineMapStore.remember(detail)
                    guard let hit = osmStepTowardHub(detail: detail, origin: origin, hubs: hubs) else {
                        return nil
                    }
                    return (detail, hit.hub, hit.step)
                }
            }

            var matched: [(detail: BusRouteDetail, hub: TransferHub, step: ParsedTransitStep)] = []
            for await item in group {
                guard let (detail, hub, step) = item else { continue }
                matched.append((detail, hub, step))
                group.cancelAll()
                break
            }
            guard let first = matched.first else { return nil }
            let refs = Array(Set(matched.map(\.detail.candidate.ref))).sorted()
            let primaryRef = refs.contains(where: { $0.caseInsensitiveCompare(busNumber) == .orderedSame })
                ? busNumber
                : (refs.first ?? first.detail.candidate.ref)
            let route = navigationRoute(
                for: first.hub,
                step: first.step,
                parent: destinationRoutes[first.hub.parentRouteIndex]
            )
            return boardingResponse(
                outcome: alternateOutcome(for: primaryRef, route: route, variantNames: refs.count > 1 ? refs : nil),
                match: (first.hub.parentRouteIndex, route),
                busNumber: primaryRef,
                allRoutes: destinationRoutes,
                directionHintOverride: alternateHint(hubName: first.hub.stopName, route: route, busNumber: primaryRef)
            )
        }
    }

    private static func osmStepTowardHub(
        detail: BusRouteDetail,
        origin: CLLocationCoordinate2D,
        hubs: [TransferHub]
    ) -> (hub: TransferHub, step: ParsedTransitStep)? {
        let stops = detail.stops
        guard stops.count >= 2 else { return nil }

        let originWalkMeters: Double = 700

        guard let originIdx = nearestStopIndex(in: stops, to: origin, maxMeters: originWalkMeters) else {
            return nil
        }

        for hub in hubs {
            let hubCoord = CLLocationCoordinate2D(latitude: hub.location.latitude, longitude: hub.location.longitude)
            guard let hubIdx = nearestStopIndex(in: stops, to: hubCoord, maxMeters: hub.matchRadiusMeters),
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

    /// 目的地まで同じ全線なら直通路線として使う。乗換停までのときだけ Google 案の後半を残す。
    private static func navigationRoute(
        for hub: TransferHub,
        step: ParsedTransitStep,
        parent: ParsedTransitRoute
    ) -> ParsedTransitRoute {
        if hub.kind == .destination {
            let meters = polylineLength(step.polylineCoordinates)
            let seconds = max(60, meters / 5.5)
            return ParsedTransitRoute(
                durationSeconds: seconds,
                durationText: nil,
                fareText: nil,
                fareAmount: nil,
                steps: [step]
            )
        }
        return replacingBusStep(in: parent, at: hub.firstBusStepIndex, with: step)
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
