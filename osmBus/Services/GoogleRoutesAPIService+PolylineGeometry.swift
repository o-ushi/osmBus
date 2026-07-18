import Foundation

extension GoogleRoutesAPIService {
    static func distanceMeters(
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

    static func decodePolyline(_ encoded: String) -> [RouteCoordinate] {
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

    static func progressAlongPolyline(
        _ coordinate: (latitude: Double, longitude: Double),
        _ polyline: [RouteCoordinate]
    ) -> Double {
        guard polyline.count >= 2 else { return 0 }

        var segmentLengths: [Double] = []
        var totalLength = 0.0
        for i in 0..<polyline.count - 1 {
            let len = distanceMeters(
                fromLatitude: polyline[i].latitude,
                fromLongitude: polyline[i].longitude,
                toLatitude: polyline[i+1].latitude,
                toLongitude: polyline[i+1].longitude
            )
            segmentLengths.append(len)
            totalLength += len
        }
        guard totalLength > 0 else { return 0 }

        var minDist = Double.infinity
        var bestProgress = 0.0
        var cumulative = 0.0

        for i in 0..<segmentLengths.count {
            let segLen = segmentLengths[i]
            let ax = polyline[i].longitude, ay = polyline[i].latitude
            let bx = polyline[i+1].longitude, by = polyline[i+1].latitude
            let px = coordinate.longitude, py = coordinate.latitude
            let dx = bx - ax, dy = by - ay
            let lenSq = dx * dx + dy * dy
            let t = lenSq < 1e-20 ? 0.0 : max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq))
            let projLat = ay + t * dy
            let projLon = ax + t * dx
            let dist = distanceMeters(
                fromLatitude: coordinate.latitude,
                fromLongitude: coordinate.longitude,
                toLatitude: projLat,
                toLongitude: projLon
            )
            if dist < minDist {
                minDist = dist
                bestProgress = (cumulative + t * segLen) / totalLength
            }
            cumulative += segLen
        }

        return bestProgress
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

    static func coordinate(
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

    static func compassBearing(from: RouteCoordinate, to: RouteCoordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return ((atan2(y, x) * 180 / .pi) + 360).truncatingRemainder(dividingBy: 360)
    }
}
