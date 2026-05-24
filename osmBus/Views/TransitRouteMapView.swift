import MapKit
import SwiftUI

struct TransitRouteMapSelection: Identifiable {
    let id: Int
    let route: ParsedTransitRoute
}

struct TransitRouteMapView: View {
    let routeIndex: Int
    let route: ParsedTransitRoute
    let origin: RouteCoordinate
    let destination: Destination

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(segments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            segment.isTransit ? Color.blue : Color.gray.opacity(0.85),
                            style: StrokeStyle(
                                lineWidth: segment.isTransit ? 6 : 4,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: segment.isTransit ? [] : [8, 6]
                            )
                        )
                }

                ForEach(stops) { stop in
                    Annotation(stop.title, coordinate: stop.coordinate, anchor: stop.annotationAnchor) {
                        stopMarker(for: stop)
                    }
                }

                ForEach(stopCountBadges) { badge in
                    Annotation("", coordinate: badge.coordinate, anchor: .center) {
                        stopCountBadge(count: badge.count)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .navigationTitle(
                AppLocaleString.formatted("osmBus_経路番号_%d", locale: locale, routeIndex + 1)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocaleString.text("閉じる", locale: locale))
                }
            }
            .safeAreaInset(edge: .bottom) {
                routeSummaryBar
            }
            .onAppear {
                cameraPosition = .region(fittedRegion)
            }
        }
    }

    private var routeSummaryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(GoogleRoutesAPIService.displayDuration(for: route, locale: locale))
                    .font(.headline)
                Spacer()
                if totalBusStopCount > 0 {
                    Label(
                        AppLocaleString.formatted("osmBus_バス停合計_%d", locale: locale, totalBusStopCount),
                        systemImage: "signpost.right.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                if let fare = GoogleRoutesAPIService.displayFare(for: route) {
                    Label(fare, systemImage: "yensign.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(GoogleRoutesAPIService.transitLineSummary(for: route))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func stopMarker(for stop: MapStopAnnotation) -> some View {
        switch stop.kind {
        case .origin:
            markerBubble(
                systemImage: "location.fill",
                tint: .green,
                label: stop.lineLabel,
                emphasized: false
            )
        case .destination:
            markerBubble(
                systemImage: "flag.checkered",
                tint: .red,
                label: nil,
                emphasized: false
            )
        case .boarding:
            namedStopMarker(
                systemImage: vehicleIcon(for: stop.vehicleType),
                tint: .blue,
                name: stop.title,
                lineLabel: stop.lineLabel,
                emphasized: false
            )
        case .transfer:
            namedStopMarker(
                systemImage: "arrow.triangle.branch",
                tint: .orange,
                name: stop.title,
                lineLabel: stop.lineLabel,
                emphasized: true
            )
        case .alight:
            namedStopMarker(
                systemImage: "figure.wave",
                tint: .indigo,
                name: stop.title,
                lineLabel: stop.lineLabel,
                emphasized: stop.emphasized
            )
        case .intermediate:
            intermediateStopDot
        }
    }

    private func stopCountBadge(count: Int) -> some View {
        Text(AppLocaleString.formatted("osmBus_あとN停_%d", locale: locale, count))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.blue.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }

    private var intermediateStopDot: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }

    private func namedStopMarker(
        systemImage: String,
        tint: Color,
        name: String,
        lineLabel: String?,
        emphasized: Bool
    ) -> some View {
        VStack(spacing: 4) {
            if let lineLabel, !lineLabel.isEmpty {
                Text(lineLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint, in: Capsule())
            }

            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: emphasized ? 120 : 96)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: emphasized ? 44 : 36, height: emphasized ? 44 : 36)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                Image(systemName: systemImage)
                    .font(.system(size: emphasized ? 18 : 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }

    private func markerBubble(
        systemImage: String,
        tint: Color,
        label: String?,
        emphasized: Bool
    ) -> some View {
        VStack(spacing: 4) {
            if let label, !label.isEmpty {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint, in: Capsule())
            }

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: emphasized ? 44 : 36, height: emphasized ? 44 : 36)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                Image(systemName: systemImage)
                    .font(.system(size: emphasized ? 18 : 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }

    private func vehicleIcon(for vehicleType: String?) -> String {
        switch vehicleType {
        case "BUS":
            return "bus.fill"
        case "SUBWAY", "METRO":
            return "tram.fill"
        case "TRAIN", "RAIL", "HEAVY_RAIL", "COMMUTER_TRAIN":
            return "train.side.front.car"
        case "LIGHT_RAIL":
            return "lightrail.fill"
        default:
            return "tram.fill"
        }
    }

    private var segments: [RouteMapSegment] {
        route.steps.enumerated().compactMap { index, step in
            let coordinates = step.polylineCoordinates.map(\.clLocationCoordinate2D)
            guard coordinates.count >= 2 else { return nil }
            return RouteMapSegment(
                id: index,
                coordinates: coordinates,
                isTransit: step.travelMode == "TRANSIT"
            )
        }
    }

    private var stops: [MapStopAnnotation] {
        var annotations: [MapStopAnnotation] = [
            MapStopAnnotation(
                id: "origin",
                title: AppLocaleString.text("osmBus_現在地", locale: locale),
                coordinate: origin.clLocationCoordinate2D,
                kind: .origin,
                lineLabel: nil,
                vehicleType: nil,
                emphasized: false,
                annotationAnchor: .bottom
            ),
        ]
        var seenCoordinates: Set<String> = []

        var transitStepIndex = 0
        let transitSteps = route.steps.enumerated().filter { $0.element.travelMode == "TRANSIT" }
        let lastTransitStepIndex = transitSteps.last?.offset

        for (stepIndex, step) in route.steps.enumerated() where step.travelMode == "TRANSIT" {
            let lineLabel = step.lineNameShort ?? step.lineName
            let isFirstTransit = transitStepIndex == 0
            let isLastTransit = stepIndex == lastTransitStepIndex

            if let location = step.departureStopLocation,
               shouldAddStop(at: location, seen: &seenCoordinates) {
                annotations.append(
                    MapStopAnnotation(
                        id: "departure-\(stepIndex)",
                        title: step.departureStopName ?? AppLocaleString.text("osmBus_バス停", locale: locale),
                        coordinate: location.clLocationCoordinate2D,
                        kind: isFirstTransit ? .boarding : .transfer,
                        lineLabel: lineLabel,
                        vehicleType: step.vehicleType,
                        emphasized: !isFirstTransit,
                        annotationAnchor: .bottom
                    )
                )
            }

            let intermediateCount = max(0, step.stopCount ?? 0)
            let intermediateStops = GoogleRoutesAPIService.interpolatedStopCoordinates(
                along: step.polylineCoordinates,
                stopCount: intermediateCount
            )
            for (intermediateIndex, location) in intermediateStops.enumerated() {
                guard shouldAddStop(at: location, seen: &seenCoordinates) else { continue }
                annotations.append(
                    MapStopAnnotation(
                        id: "intermediate-\(stepIndex)-\(intermediateIndex)",
                        title: AppLocaleString.formatted(
                            "osmBus_経由停_%d",
                            locale: locale,
                            intermediateIndex + 1
                        ),
                        coordinate: location.clLocationCoordinate2D,
                        kind: .intermediate,
                        lineLabel: lineLabel,
                        vehicleType: step.vehicleType,
                        emphasized: false,
                        annotationAnchor: .center
                    )
                )
            }

            if let location = step.arrivalStopLocation,
               shouldAddStop(at: location, seen: &seenCoordinates) {
                annotations.append(
                    MapStopAnnotation(
                        id: "arrival-\(stepIndex)",
                        title: step.arrivalStopName ?? AppLocaleString.text("osmBus_バス停", locale: locale),
                        coordinate: location.clLocationCoordinate2D,
                        kind: .alight,
                        lineLabel: lineLabel,
                        vehicleType: step.vehicleType,
                        emphasized: isLastTransit,
                        annotationAnchor: .bottom
                    )
                )
            }

            transitStepIndex += 1
        }

        let destinationCoordinate = CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        if shouldAddStop(at: RouteCoordinate(latitude: destination.latitude, longitude: destination.longitude), seen: &seenCoordinates) {
            annotations.append(
                MapStopAnnotation(
                    id: "destination",
                    title: destination.name,
                    coordinate: destinationCoordinate,
                    kind: .destination,
                    lineLabel: nil,
                    vehicleType: nil,
                    emphasized: false,
                    annotationAnchor: .bottom
                )
            )
        }

        return annotations
    }

    private var stopCountBadges: [StopCountBadge] {
        route.steps.enumerated().compactMap { stepIndex, step in
            guard step.travelMode == "TRANSIT",
                  step.vehicleType == "BUS",
                  let stopCount = step.stopCount,
                  stopCount > 0,
                  let midpoint = GoogleRoutesAPIService.midpointCoordinate(on: step.polylineCoordinates) else {
                return nil
            }

            return StopCountBadge(
                id: "badge-\(stepIndex)",
                coordinate: midpoint.clLocationCoordinate2D,
                count: stopCount
            )
        }
    }

    private var totalBusStopCount: Int {
        route.steps.reduce(0) { partial, step in
            guard step.travelMode == "TRANSIT", step.vehicleType == "BUS" else { return partial }
            let intermediate = max(0, step.stopCount ?? 0)
            return partial + intermediate + 2
        }
    }

    private func shouldAddStop(at coordinate: RouteCoordinate, seen: inout Set<String>) -> Bool {
        let key = coordinateKey(coordinate)
        guard !seen.contains(key) else { return false }
        seen.insert(key)
        return true
    }

    private func coordinateKey(_ coordinate: RouteCoordinate) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private var fittedRegion: MKCoordinateRegion {
        var coordinates = segments.flatMap(\.coordinates)
        coordinates.append(origin.clLocationCoordinate2D)
        coordinates.append(
            CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        )
        coordinates.append(contentsOf: stops.map(\.coordinate))
        coordinates.append(contentsOf: stopCountBadges.map(\.coordinate))

        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: destination.latitude,
                    longitude: destination.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latitudeDelta = max(0.01, (maxLat - minLat) * 1.45)
        let longitudeDelta = max(0.01, (maxLon - minLon) * 1.45)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private struct RouteMapSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let isTransit: Bool
}

private struct StopCountBadge: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
}

private struct MapStopAnnotation: Identifiable {
    enum Kind {
        case origin
        case destination
        case boarding
        case transfer
        case alight
        case intermediate
    }

    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    let lineLabel: String?
    let vehicleType: String?
    let emphasized: Bool
    let annotationAnchor: UnitPoint
}

private extension RouteCoordinate {
    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
