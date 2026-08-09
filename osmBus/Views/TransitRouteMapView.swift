import Combine
import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

// MARK: - Shared Google Maps components (used by all map views in this target)

struct GMapPolylineData: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: UIColor
    let width: Float
    let dashed: Bool
}

struct GMapMarkerData: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let icon: UIImage?
    let groundAnchor: CGPoint
    let zIndex: Int32
    let title: String
}

private struct _GoogleMSMapWrapper: UIViewRepresentable {
    let cacheKey: String
    let polylines: [GMapPolylineData]
    let markers: [GMapMarkerData]
    var shouldFollowUser: Bool = false
    var fitBoundsOnAppear: GMSCoordinateBounds? = nil
    var onSetup: ((GMSMapView) -> Void)? = nil
    var onTap: ((CLLocationCoordinate2D) -> Void)? = nil

    @EnvironmentObject private var locationService: LocationService

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(target: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 14)
        options.frame = .zero
        let mapView = GMSMapView(options: options)
        // 自前の LocationService の位置を使うため、Google Maps SDK 自体の GPS 追跡は使わない
        // (二重に GPS が起動して電力を余計に消費するのを防ぐ)。現在地は自前のマーカーで描画する。
        mapView.isMyLocationEnabled = false
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.delegate = context.coordinator
        return mapView
    }

    static func dismantleUIView(_ uiView: GMSMapView, coordinator: Coordinator) {
        coordinator.renderedPolylines.forEach { $0.map = nil }
        coordinator.renderedMarkers.forEach { $0.map = nil }
        coordinator.myLocationMarker?.map = nil
        coordinator.renderedPolylines = []
        coordinator.renderedMarkers = []
        coordinator.polylineIDs = []
        coordinator.markerIDs = []
        uiView.delegate = nil
        uiView.removeFromSuperview()
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let c = context.coordinator

        if !c.didSetupInitialCamera {
            c.didSetupInitialCamera = true
            if let bounds = fitBoundsOnAppear, bounds.isValid {
                DispatchQueue.main.async {
                    mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
                }
            }
            onSetup?(mapView)
        }

        let newPolylineIDs = polylines.map(\.id)
        if c.polylineIDs != newPolylineIDs {
            c.renderedPolylines.forEach { $0.map = nil }
            c.renderedPolylines = []
            c.polylineIDs = newPolylineIDs
            c.pendingPolylines = polylines
            c.schedulePolylineBatch(on: mapView)
        }

        let newMarkerIDs = markers.map(\.id)
        if c.markerIDs != newMarkerIDs {
            c.renderedMarkers.forEach { $0.map = nil }
            c.renderedMarkers = markers.map { data in
                let m = GMSMarker(position: data.coordinate)
                m.icon = data.icon
                m.groundAnchor = data.groundAnchor
                m.zIndex = data.zIndex
                m.title = data.title
                m.map = mapView
                return m
            }
            c.markerIDs = newMarkerIDs
        } else {
            for (rendered, data) in zip(c.renderedMarkers, markers) {
                if rendered.position.latitude != data.coordinate.latitude
                    || rendered.position.longitude != data.coordinate.longitude {
                    rendered.position = data.coordinate
                }
            }
        }

        let userCoordinate = locationService.currentLocation
        if let userCoordinate {
            if let marker = c.myLocationMarker {
                marker.position = userCoordinate
            } else {
                let marker = GMSMarker(position: userCoordinate)
                marker.icon = TransitMapMarkerIcons.myLocationDot()
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.zIndex = 20
                marker.isTappable = false
                marker.map = mapView
                c.myLocationMarker = marker
            }
        } else if let marker = c.myLocationMarker {
            marker.map = nil
            c.myLocationMarker = nil
        }

        if shouldFollowUser, let coord = userCoordinate {
            if let last = c.lastFollowed,
               abs(coord.latitude - last.latitude) < 0.00005,
               abs(coord.longitude - last.longitude) < 0.00005 { } else {
                mapView.animate(toLocation: coord)
                c.lastFollowed = coord
            }
        }

        c.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: _GoogleMSMapWrapper
        var renderedPolylines: [GMSPolyline] = []
        var renderedMarkers: [GMSMarker] = []
        var polylineIDs: [String] = []
        var markerIDs: [String] = []
        var didSetupInitialCamera = false
        var lastFollowed: CLLocationCoordinate2D?
        var pendingPolylines: [GMapPolylineData] = []
        var isSchedulingPolylines = false
        var myLocationMarker: GMSMarker?

        init(_ parent: _GoogleMSMapWrapper) { self.parent = parent }

        func schedulePolylineBatch(on mapView: GMSMapView) {
            guard !isSchedulingPolylines else { return }
            isSchedulingPolylines = true
            appendNextPolylineBatch(on: mapView)
        }

        private func appendNextPolylineBatch(on mapView: GMSMapView) {
            guard !pendingPolylines.isEmpty else {
                isSchedulingPolylines = false
                return
            }
            let batch = Array(pendingPolylines.prefix(2))
            pendingPolylines.removeFirst(batch.count)
            for data in batch {
                renderedPolylines.append(makePolyline(data, on: mapView))
            }
            if pendingPolylines.isEmpty {
                isSchedulingPolylines = false
            } else {
                DispatchQueue.main.async { [weak self, weak mapView] in
                    guard let self, let mapView else { return }
                    self.appendNextPolylineBatch(on: mapView)
                }
            }
        }

        private func makePolyline(_ data: GMapPolylineData, on mapView: GMSMapView) -> GMSPolyline {
            let path = GMSMutablePath()
            data.coordinates.forEach { path.add($0) }
            let pl = GMSPolyline(path: path)
            pl.strokeColor = data.color
            pl.strokeWidth = CGFloat(data.width)
            if data.dashed {
                pl.spans = GMSStyleSpans(
                    path,
                    [.solidColor(data.color), .solidColor(.clear)],
                    [10, 7],
                    .projected
                )
            }
            pl.map = mapView
            return pl
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            parent.onTap?(coordinate)
        }
    }
}

// MARK: - GoogleMapView (SwiftUI wrapper with trial gating)

struct GoogleMapView: View {
    let polylines: [GMapPolylineData]
    let markers: [GMapMarkerData]
    var showCustomLocationButton: Bool = false
    var locationButtonFallback: CLLocationCoordinate2D? = nil
    var shouldFollowUser: Bool = false
    var fitBoundsOnAppear: GMSCoordinateBounds? = nil
    var onSetup: ((GMSMapView) -> Void)? = nil
    var onTap: ((CLLocationCoordinate2D) -> Void)? = nil
    var trialSignature: String = "maps"

    @Environment(SharedMapsTrialStore.self) private var mapsTrialStore
    @Environment(\.locale) private var locale
    @State private var showsPrivacySheet = false
    @State private var showsAPISettings = false
    @State private var mapBox = GMSMapViewBox()

    var body: some View {
        if !ThirdPartyDataConsent.isGranted {
            consentGateView
        } else if mapsTrialStore.canShowMap {
            _GoogleMSMapWrapper(
                cacheKey: trialSignature,
                polylines: polylines,
                markers: markers,
                shouldFollowUser: shouldFollowUser,
                fitBoundsOnAppear: fitBoundsOnAppear,
                onSetup: { mapView in
                    mapBox.view = mapView
                    onSetup?(mapView)
                },
                onTap: onTap
            )
            .overlay(alignment: .bottomTrailing) {
                if showCustomLocationButton {
                    MapLocationButton(
                        mapBox: mapBox,
                        fallbackCoordinate: locationButtonFallback
                    )
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
            .onAppear {
                mapsTrialStore.consumeTrialIfNeeded(signature: trialSignature)
            }
        } else {
            mapTrialGateView
        }
    }

    private var consentGateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(AppLocaleString.text("第三者送信_同意が必要", locale: locale))
                .multilineTextAlignment(.center)
            Button(AppLocaleString.text("プライバシーとデータ", locale: locale)) {
                showsPrivacySheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showsPrivacySheet) {
            NavigationStack {
                PrivacyDataView()
            }
            .environment(\.locale, locale)
        }
    }

    private var mapTrialGateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(AppLocaleString.text("Maps_お試し終了_タイトル", locale: locale))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(AppLocaleString.text("Maps_お試し終了_本文", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(AppLocaleString.text("Maps_設定に進む", locale: locale)) {
                showsAPISettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showsAPISettings) {
            AppSettingsView(opensAPISettingsOnAppear: true)
                .environment(\.locale, locale)
        }
    }
}

// MARK: - Map location button (custom overlay; stays visible above route info bars)

/// Holds a GMSMapView without triggering SwiftUI re-renders when assigned.
final class GMSMapViewBox {
    weak var view: GMSMapView?

    func moveToCurrentLocation(coordinate: CLLocationCoordinate2D?, zoom: Float = 15) {
        guard let view, let coord = coordinate else { return }
        view.animate(to: GMSCameraPosition(target: coord, zoom: zoom))
    }
}

struct MapLocationButton: View {
    let mapBox: GMSMapViewBox
    var fallbackCoordinate: CLLocationCoordinate2D?

    @EnvironmentObject private var locationService: LocationService
    @Environment(\.locale) private var locale

    private static let googleBlue = Color(red: 0.26, green: 0.52, blue: 0.96)

    var body: some View {
        Button {
            mapBox.moveToCurrentLocation(coordinate: locationService.currentLocation ?? fallbackCoordinate)
        } label: {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Self.googleBlue)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .systemBackground), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocaleString.text("現在地に移動", locale: locale))
    }
}

// MARK: - TransitRouteMapSelection

struct TransitRouteMapSelection: Identifiable {
    let id: Int
    let route: ParsedTransitRoute
}

/// 乗車中の経路地図シート用。表示時点のスナップショットを保持し、親の再描画ループを防ぐ。
struct BoardingRouteMapSheetModel: Identifiable {
    let id: Int
    let route: ParsedTransitRoute
    let origin: RouteCoordinate
    let destination: Destination
    let routeOptionCount: Int
    var ridingBusNumber: String? = nil
    var ridingAlightCoordinate: RouteCoordinate? = nil
}

// MARK: - TransitRouteMapView

struct TransitRouteMapView: View {
    let routeIndex: Int
    let route: ParsedTransitRoute
    let origin: RouteCoordinate
    let destination: Destination
    var ridingBusNumber: String? = nil
    var ridingAlightCoordinate: RouteCoordinate? = nil
    var allRoutes: [ParsedTransitRoute] = []
    var routeOptionCount: Int = 1
    var onLoadRouteOptions: (() -> [ParsedTransitRoute])? = nil
    var onSwitchRoute: ((Int) -> Void)? = nil
    var onMapReady: (() -> Void)? = nil
    var onSelectRidingBus: ((Int, String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var routeOverride: RouteOverride? = nil
    @State private var showsRouteSwitcher = false
    @State private var loadedRouteOptions: [ParsedTransitRoute] = []
    @State private var mapBox = GMSMapViewBox()
    @State private var cachedPolylines: [GMapPolylineData] = []
    @State private var cachedMarkers: [GMapMarkerData] = []
    @State private var isMapEngineReady = false
    @State private var lastKnownUserCoordinate: CLLocationCoordinate2D? = nil

    @EnvironmentObject private var locationService: LocationService

    private struct RouteOverride {
        let index: Int
        let route: ParsedTransitRoute
    }

    private var displayedRouteOptionCount: Int {
        max(routeOptionCount, allRoutes.count, loadedRouteOptions.count, 1)
    }

    private var routeOptionsForSwitcher: [ParsedTransitRoute] {
        if !loadedRouteOptions.isEmpty { return loadedRouteOptions }
        if !allRoutes.isEmpty { return allRoutes }
        return [displayedRoute]
    }

    private var displayedRouteIndex: Int { routeOverride?.index ?? routeIndex }
    private var displayedRoute: ParsedTransitRoute { routeOverride?.route ?? route }

    private var displayedRouteContainsRidingBus: Bool {
        guard let ridingBusNumber else { return true }
        let lines = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: displayedRoute)
        return lines.contains { $0.uppercased() == ridingBusNumber.uppercased() }
    }

    private var currentLegAlightingCoordinate: CLLocationCoordinate2D {
        if let coord = ridingAlightCoordinate {
            return CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        }
        let busStep = displayedRoute.steps.first(where: {
            $0.travelMode == "TRANSIT" && $0.vehicleType == "BUS"
        })
        if let loc = busStep?.arrivalStopLocation {
            return CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        }
        return CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
    }

    private var effectiveUserCoordinate: CLLocationCoordinate2D? {
        locationService.currentLocation ?? lastKnownUserCoordinate
    }

    private var distanceToDestination: Double? {
        guard let coord = effectiveUserCoordinate else { return nil }
        let alight = currentLegAlightingCoordinate
        return GoogleRoutesAPIService.distanceMeters(
            fromLatitude: coord.latitude,
            fromLongitude: coord.longitude,
            toLatitude: alight.latitude,
            toLongitude: alight.longitude
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isMapEngineReady {
                    mapLayer
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(AppLocaleString.text("経路読込中", locale: locale))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    routeHeaderBusLines
                }
                .hideSharedBackgroundIfAvailable()
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if displayedRouteOptionCount > 1 {
                        Button { openRouteSwitcher() } label: {
                            HStack(spacing: 3) {
                                Text(AppLocaleString.formatted("経路番号_%d", locale: locale, displayedRouteIndex + 1))
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        }
                    } else {
                        Text(AppLocaleString.formatted("経路番号_%d", locale: locale, displayedRouteIndex + 1))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showsRouteSwitcher) {
                routeSwitcherSheet
            }
            .task { await bootMapEngine() }
            .syncMapLiveLocation(lastKnown: $lastKnownUserCoordinate)
        }
    }

    private var mapLayer: some View {
        GoogleMapView(
            polylines: cachedPolylines,
            markers: cachedMarkers,
            shouldFollowUser: false,
            fitBoundsOnAppear: nil,
            onSetup: { mapView in
                mapBox.view = mapView
                mapView.camera = GMSCameraPosition(
                    target: origin.clLocationCoordinate2D,
                    zoom: 14
                )
            },
            trialSignature: "maps-transit"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    MapLocationButton(
                        mapBox: mapBox,
                        fallbackCoordinate: origin.clLocationCoordinate2D
                    )
                    .padding(.trailing, 12)
                }
                routeSummaryBar
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @MainActor
    private func bootMapEngine() async {
        guard !isMapEngineReady else { return }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 150_000_000)
        isMapEngineReady = true
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await loadMapOverlays()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 250_000_000)
        onMapReady?()
    }

    @MainActor
    private func loadMapOverlays() async {
        guard cachedPolylines.isEmpty else { return }

        let polylines = buildPolylines()
        await Task.yield()
        cachedPolylines = polylines

        try? await Task.sleep(nanoseconds: 120_000_000)
        await Task.yield()

        cachedMarkers = buildMapMarkers()
        await Task.yield()
        fitMapToRoute()
    }

    private func openRouteSwitcher() {
        if loadedRouteOptions.isEmpty {
            loadedRouteOptions = onLoadRouteOptions?() ?? allRoutes
        }
        showsRouteSwitcher = true
    }

    // MARK: - Route switching

    private var routeSwitcherSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(routeOptionsForSwitcher.enumerated()), id: \.offset) { index, r in
                    Button {
                        selectRoute(at: index, newRoute: r)
                    } label: {
                        RouteSwitcherRow(
                            index: index,
                            route: r,
                            isSelected: index == displayedRouteIndex,
                            locale: locale,
                            ridingBusNumber: ridingBusNumber
                        )
                    }
                    .foregroundStyle(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(AppLocaleString.text("経路一覧", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
    }

    private func selectRoute(at index: Int, newRoute: ParsedTransitRoute) {
        showsRouteSwitcher = false
        routeOverride = RouteOverride(index: index, route: newRoute)
        cachedPolylines = []
        cachedMarkers = []
        Task { @MainActor in
            await loadMapOverlays()
        }
        onSwitchRoute?(index)
    }

    // MARK: - Route summary bar

    private var routeSummaryBar: some View {
        RouteMapSummaryBar(
            durationText: GoogleRoutesAPIService.displayDuration(for: displayedRoute, locale: locale),
            distanceMeters: distanceToDestination,
            showsDistance: displayedRouteContainsRidingBus,
            fareText: GoogleRoutesAPIService.displayFare(for: displayedRoute),
            locale: locale
        )
    }

    @ViewBuilder
    private var routeHeaderBusLines: some View {
        let busLines = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: displayedRoute)
        Group {
            if busLines.isEmpty {
                Text(GoogleRoutesAPIService.transitLineSummary(for: displayedRoute))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                TransitBusLineBadgesRow(
                    lines: busLines,
                    ridingBusNumber: ridingBusNumber,
                    onLongPress: onSelectRidingBus.map { callback in
                        { line in callback(displayedRouteIndex, line) }
                    }
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private func buildPolylines() -> [GMapPolylineData] {
        segments.map { seg in
            GMapPolylineData(
                id: "seg-\(seg.id)",
                coordinates: decimateCoordinates(seg.coordinates),
                color: transitSegmentColor(seg),
                width: seg.isTransit ? 6 : 4,
                dashed: !seg.isTransit
            )
        }
    }

    private func transitSegmentColor(_ seg: RouteMapSegment) -> UIColor {
        guard seg.isTransit else { return UIColor.gray.withAlphaComponent(0.85) }
        switch seg.vehicleType {
        case "SUBWAY", "METRO", "HEAVY_RAIL", "COMMUTER_TRAIN", "TRAIN", "RAIL", "LIGHT_RAIL":
            return .systemGreen
        default:
            return .systemBlue
        }
    }

    private func decimateCoordinates(
        _ coordinates: [CLLocationCoordinate2D],
        maxPoints: Int = 250
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let lastIndex = coordinates.count - 1
        return (0..<maxPoints).map { i in
            coordinates[min(lastIndex, (i * lastIndex) / (maxPoints - 1))]
        }
    }

    private func buildMapMarkers() -> [GMapMarkerData] {
        var result: [GMapMarkerData] = []

        for stop in stops {
            let anchor: CGPoint = stop.annotationAnchor == .center
                ? CGPoint(x: 0.5, y: 0.5)
                : CGPoint(x: 0.5, y: 1.0)
            result.append(GMapMarkerData(
                id: stop.id,
                coordinate: stop.coordinate,
                icon: TransitMapMarkerIcons.icon(for: stop.kind, vehicleType: stop.vehicleType),
                groundAnchor: anchor,
                zIndex: markerZIndex(for: stop.kind),
                title: stop.title
            ))
        }

        return result
    }

    private func fitMapToRoute() {
        guard let mapView = mapBox.view else { return }
        var bounds = GMSCoordinateBounds()
        for seg in segments {
            for coord in seg.coordinates { bounds = bounds.includingCoordinate(coord) }
        }
        bounds = bounds.includingCoordinate(origin.clLocationCoordinate2D)
        bounds = bounds.includingCoordinate(
            CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        )
        guard bounds.isValid else { return }
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
    }

    private func markerZIndex(for kind: MapStopAnnotation.Kind) -> Int32 {
        switch kind {
        case .destination: return 10
        case .transfer: return 9
        case .boarding, .alight: return 8
        }
    }

    // MARK: - Data computation

    private var segments: [RouteMapSegment] {
        displayedRoute.steps.enumerated().compactMap { index, step in
            let coordinates = step.polylineCoordinates.map(\.clLocationCoordinate2D)
            guard coordinates.count >= 2 else { return nil }
            return RouteMapSegment(
                id: index,
                coordinates: coordinates,
                isTransit: step.travelMode == "TRANSIT",
                vehicleType: step.vehicleType
            )
        }
    }

    /// 乗車中バスの区間がこのルート内で何番目のステップか。手前の区間(既に乗り換え済み)の
    /// 乗換ピンを誤表示しないよう、これより前のステップは地図に出さない。
    private var ridingLegStepIndex: Int? {
        guard let ridingBusNumber else { return nil }
        return displayedRoute.steps.firstIndex { step in
            step.travelMode == "TRANSIT" && step.vehicleType == "BUS" &&
            GoogleRoutesAPIService.stepMatchesBusNumber(step, busNumber: ridingBusNumber)
        }
    }

    private var stops: [MapStopAnnotation] {
        var annotations: [MapStopAnnotation] = []
        var seenCoordinates: Set<String> = []

        let legStartIndex = ridingLegStepIndex ?? 0
        let transitSteps = displayedRoute.steps.enumerated().filter { $0.element.travelMode == "TRANSIT" }
        let lastTransitStepIndex = transitSteps.last?.offset

        for (stepIndex, step) in displayedRoute.steps.enumerated() where step.travelMode == "TRANSIT" {
            guard stepIndex >= legStartIndex else { continue }

            let lineLabel = step.lineNameShort ?? step.lineName
            let isFirstTransit = stepIndex == legStartIndex
            let isLastTransit = stepIndex == lastTransitStepIndex

            if let location = step.departureStopLocation,
               shouldAddStop(at: location, seen: &seenCoordinates) {
                annotations.append(MapStopAnnotation(
                    id: "departure-\(stepIndex)",
                    title: step.departureStopName ?? AppLocaleString.text("バス停", locale: locale),
                    coordinate: location.clLocationCoordinate2D,
                    kind: isFirstTransit ? .boarding : .transfer,
                    lineLabel: lineLabel,
                    vehicleType: step.vehicleType,
                    emphasized: !isFirstTransit,
                    annotationAnchor: .bottom
                ))
            }

            if let location = step.arrivalStopLocation,
               shouldAddStop(at: location, seen: &seenCoordinates) {
                annotations.append(MapStopAnnotation(
                    id: "arrival-\(stepIndex)",
                    title: step.arrivalStopName ?? AppLocaleString.text("バス停", locale: locale),
                    coordinate: location.clLocationCoordinate2D,
                    kind: .alight,
                    lineLabel: lineLabel,
                    vehicleType: step.vehicleType,
                    emphasized: isLastTransit,
                    annotationAnchor: .bottom
                ))
            }
        }

        let destinationCoordinate = CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        if shouldAddStop(
            at: RouteCoordinate(latitude: destination.latitude, longitude: destination.longitude),
            seen: &seenCoordinates
        ) {
            annotations.append(MapStopAnnotation(
                id: "destination",
                title: destination.name,
                coordinate: destinationCoordinate,
                kind: .destination,
                lineLabel: nil,
                vehicleType: nil,
                emphasized: false,
                annotationAnchor: .bottom
            ))
        }

        return annotations
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
}

// MARK: - Lightweight map marker icons (UIKit only; avoids SwiftUI ImageRenderer on main thread)

private enum TransitMapMarkerIcons {
    static func icon(for kind: MapStopAnnotation.Kind, vehicleType: String?) -> UIImage {
        switch kind {
        case .destination:
            return pin(systemName: "flag.checkered", tint: .systemRed)
        case .boarding:
            return pin(systemName: vehicleSymbol(for: vehicleType), tint: .systemOrange)
        case .transfer:
            return pin(systemName: "arrow.triangle.branch", tint: .systemOrange, diameter: 40)
        case .alight:
            return pin(systemName: "figure.wave", tint: .systemIndigo)
        }
    }

    private static func pin(systemName: String, tint: UIColor, diameter: CGFloat = 36) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: diameter * 0.38, weight: .semibold)
        return UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { _ in
            UIColor.white.setFill()
            let circle = UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: diameter - 2, height: diameter - 2))
            circle.fill()
            tint.setStroke()
            circle.lineWidth = 2
            circle.stroke()
            if let symbol = UIImage(systemName: systemName, withConfiguration: config)?
                .withTintColor(tint, renderingMode: .alwaysOriginal) {
                symbol.draw(at: CGPoint(
                    x: (diameter - symbol.size.width) / 2,
                    y: (diameter - symbol.size.height) / 2
                ))
            }
        }
    }

    /// 自前追跡の現在地マーカー。Google Maps 純正の青い現在地ドットの簡易版。
    static func myLocationDot() -> UIImage {
        let diameter: CGFloat = 22
        return UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { _ in
            let outerRect = CGRect(x: 1, y: 1, width: diameter - 2, height: diameter - 2)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: outerRect).fill()

            let innerInset: CGFloat = 3
            let innerRect = outerRect.insetBy(dx: innerInset, dy: innerInset)
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: innerRect).fill()
        }
    }

    private static func vehicleSymbol(for vehicleType: String?) -> String {
        switch vehicleType {
        case "BUS": return "bus.fill"
        case "SUBWAY", "METRO": return "tram.fill"
        case "TRAIN", "RAIL", "HEAVY_RAIL", "COMMUTER_TRAIN": return "train.side.front.car"
        case "LIGHT_RAIL": return "lightrail.fill"
        default: return "tram.fill"
        }
    }
}

// MARK: - Route summary bar

struct RouteMapSummaryBar: View {
    let durationText: String
    let distanceMeters: Double?
    var showsDistance: Bool = true
    let fareText: String?
    let locale: Locale

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(durationText)
                .font(.headline)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if showsDistance {
                distanceLabel
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            fareLabel
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var distanceLabel: some View {
        let prefix = AppLocaleString.text("直線距離", locale: locale)
        if let meters = distanceMeters {
            let formatted = meters < 1000
                ? String(format: "%.0f m", meters)
                : String(format: "%.1f km", meters / 1000)
            Label(
                "\(prefix) \(formatted)",
                systemImage: "location.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        } else {
            Label(
                "\(prefix) \(AppLocaleString.text("取得中…", locale: locale))",
                systemImage: "location.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder
    private var fareLabel: some View {
        if let fare = fareText {
            Text(fare)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
        } else {
            Text(AppLocaleString.text("運賃不明", locale: locale))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Bus line badges

struct TransitBusLineBadgeLabel: View {
    let text: String
    var isRidingBus: Bool = false
    var font: Font = .subheadline.weight(.bold)
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var cornerRadius: CGFloat = 6

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                isRidingBus ? Color.orange : AppTheme.brandBlue,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

struct TransitBusLineBadgesRow: View {
    let lines: [String]
    var ridingBusNumber: String? = nil
    var font: Font = .subheadline.weight(.bold)
    var badgeHorizontalPadding: CGFloat = 8
    var badgeVerticalPadding: CGFloat = 4
    var onLongPress: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if index > 0 {
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
                TransitBusLineBadgeLabel(
                    text: line,
                    isRidingBus: ridingBusNumber.map { line.uppercased() == $0.uppercased() } ?? false,
                    font: font,
                    horizontalPadding: badgeHorizontalPadding,
                    verticalPadding: badgeVerticalPadding
                )
                .onLongPressGesture {
                    guard let onLongPress else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onLongPress(line)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

extension ToolbarContent {
    @ToolbarContentBuilder
    func hideSharedBackgroundIfAvailable() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Route switcher row

private struct RouteSwitcherRow: View {
    let index: Int
    let route: ParsedTransitRoute
    let isSelected: Bool
    let locale: Locale
    var ridingBusNumber: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                let busLines = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: route)
                if busLines.isEmpty {
                    Text(GoogleRoutesAPIService.transitLineSummary(for: route))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    TransitBusLineBadgesRow(lines: busLines, ridingBusNumber: ridingBusNumber)
                }
                HStack(spacing: 6) {
                    Text(AppLocaleString.formatted("経路番号_%d", locale: locale, index + 1))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    Text(GoogleRoutesAPIService.displayDuration(for: route, locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Private model types

private struct RouteMapSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let isTransit: Bool
    let vehicleType: String?
}

private struct MapStopAnnotation: Identifiable {
    enum Kind {
        case destination, boarding, transfer, alight
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

// MARK: - Live location sync for map footers

private struct MapLiveLocationSyncModifier: ViewModifier {
    @EnvironmentObject private var locationService: LocationService
    @Binding var lastKnownCoordinate: CLLocationCoordinate2D?

    func body(content: Content) -> some View {
        content
            .onAppear {
                locationService.refreshCurrentFromCache()
                ingest(locationService.currentLocation)
            }
            .onReceive(locationService.$currentLocation) { coordinate in
                ingest(coordinate)
            }
    }

    private func ingest(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return }
        lastKnownCoordinate = coordinate
    }
}

extension View {
    func syncMapLiveLocation(lastKnown: Binding<CLLocationCoordinate2D?>) -> some View {
        modifier(MapLiveLocationSyncModifier(lastKnownCoordinate: lastKnown))
    }
}
