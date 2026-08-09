import Combine
import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

// MARK: - Search state machine

private enum RouteSearchState {
    case idle
    case searching
    case multipleCandidates([BusRouteCandidate])
    case loadingRoute(BusRouteCandidate)
    case loaded(BusRouteDetail)

    var isLoading: Bool {
        switch self { case .searching, .loadingRoute: return true; default: return false }
    }

    var loadedDetail: BusRouteDetail? {
        if case .loaded(let d) = self { return d }; return nil
    }

    var loadingRef: String? {
        if case .loadingRoute(let c) = self { return c.ref }; return nil
    }
}

// MARK: - View

struct BusRouteMapView: View {
    var currentLatitude: Double?
    var currentLongitude: Double?
    var destination: Destination?
    var isRidingMode: Bool = false
    var initialRouteDetail: BusRouteDetail? = nil
    var initialRouteCandidate: BusRouteCandidate? = nil
    var ridingDurationText: String? = nil
    var ridingFareText: String? = nil
    var onStartRiding: ((_ routeRef: String, _ candidate: BusRouteCandidate, _ detail: BusRouteDetail) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var routeNumberInput = ""
    @State private var searchState: RouteSearchState
    @State private var showsCandidateSheet = false
    @State private var errorMessage: String?
    @State private var showsError = false
    @State private var mapBox = GMSMapViewBox()
    @State private var searchTask: Task<Void, Never>?
    @State private var isKeypadVisible: Bool
    @State private var clearsOnNextInput = false
    @State private var ridingActive: Bool
    @State private var cachedPolylines: [GMapPolylineData] = []
    @State private var cachedMarkers: [GMapMarkerData] = []
    @State private var lastKnownUserCoordinate: CLLocationCoordinate2D? = nil

    @EnvironmentObject private var locationService: LocationService

    init(
        currentLatitude: Double? = nil,
        currentLongitude: Double? = nil,
        destination: Destination? = nil,
        isRidingMode: Bool = false,
        initialRouteDetail: BusRouteDetail? = nil,
        initialRouteCandidate: BusRouteCandidate? = nil,
        ridingDurationText: String? = nil,
        ridingFareText: String? = nil,
        onStartRiding: ((_ routeRef: String, _ candidate: BusRouteCandidate, _ detail: BusRouteDetail) -> Void)? = nil
    ) {
        self.currentLatitude = currentLatitude
        self.currentLongitude = currentLongitude
        self.destination = destination
        self.isRidingMode = isRidingMode
        self.initialRouteDetail = initialRouteDetail
        self.initialRouteCandidate = initialRouteCandidate
        self.ridingDurationText = ridingDurationText
        self.ridingFareText = ridingFareText
        self.onStartRiding = onStartRiding
        _ridingActive = State(initialValue: isRidingMode)
        _isKeypadVisible = State(initialValue: !isRidingMode)
        if isRidingMode, let detail = initialRouteDetail {
            _searchState = State(initialValue: .loaded(detail))
        } else {
            _searchState = State(initialValue: .idle)
        }
    }

    private var displayedRidingDetail: BusRouteDetail? {
        guard ridingActive else { return nil }
        return searchState.loadedDetail ?? initialRouteDetail
    }

    private var contextCoordinate: CLLocationCoordinate2D? {
        guard let lat = currentLatitude, let lon = currentLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var effectiveUserCoordinate: CLLocationCoordinate2D? {
        locationService.currentLocation ?? lastKnownUserCoordinate ?? contextCoordinate
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    GoogleMapView(
                        polylines: cachedPolylines,
                        markers: cachedMarkers,
                        shouldFollowUser: false,
                        onSetup: { mapView in
                            mapBox.view = mapView
                            if let coord = contextCoordinate {
                                mapView.camera = GMSCameraPosition(target: coord, zoom: ridingActive ? 15 : 13)
                            }
                        },
                        trialSignature: "maps-busroute"
                    )
                    .overlay { mapOverlays }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            HStack {
                                Spacer()
                                MapLocationButton(
                                    mapBox: mapBox,
                                    fallbackCoordinate: contextCoordinate
                                )
                                .padding(.trailing, ridingActive ? 12 : 10)
                            }
                            if !ridingActive, let detail = searchState.loadedDetail {
                                routeInfoBar(detail: detail)
                            }
                            if ridingActive, let detail = displayedRidingDetail {
                                ridingSummaryBar(detail: detail)
                            }
                        }
                        .padding(.bottom, isKeypadVisible ? geo.size.height * 0.45 + 8 : 0)
                    }
                    .ignoresSafeArea(edges: .bottom)

                    if isKeypadVisible {
                        BusKeypadView(
                            busNumber: routeNumberInput,
                            canSubmit: !routeNumberInput.isEmpty && !searchState.isLoading,
                            onCharacter: {
                                if clearsOnNextInput {
                                    routeNumberInput = ""
                                    clearsOnNextInput = false
                                }
                                routeNumberInput += $0
                            },
                            onSubmit: {
                                startSearch()
                                clearsOnNextInput = true
                            },
                            onClear: {
                                clearsOnNextInput = false
                                if searchState.loadedDetail != nil || searchState.isLoading {
                                    clearRoute()
                                } else {
                                    routeNumberInput = ""
                                }
                            }
                        )
                        .busMainScreenStyled()
                        .padding(.horizontal, AppTheme.screenPadding)
                        .padding(.bottom, 8)
                        .frame(height: geo.size.height * 0.45)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if case .loaded(let detail) = searchState, cachedPolylines.isEmpty {
                    rebuildMapLayers(from: detail)
                }
                loadInitialRidingRouteIfNeeded()
            }
            .syncMapLiveLocation(lastKnown: $lastKnownUserCoordinate)
            .onDisappear(perform: releaseMapResources)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showsCandidateSheet, onDismiss: {
                if case .multipleCandidates = searchState { searchState = .idle }
            }) {
                candidateSheet
            }
            .alert(
                AppLocaleString.text("路線図_エラー_タイトル", locale: locale),
                isPresented: $showsError
            ) {
                Button(AppLocaleString.text("OK", locale: locale), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Map data

    private func rebuildMapLayers(from detail: BusRouteDetail) {
        cachedPolylines = detail.polylineSegments.enumerated().compactMap { index, seg in
            guard seg.count >= 2 else { return nil }
            return GMapPolylineData(
                id: "route-seg-\(index)",
                coordinates: seg,
                color: .systemBlue,
                width: 5,
                dashed: false
            )
        }
        var markers: [GMapMarkerData] = []
        if let dest = destination {
            markers.append(GMapMarkerData(
                id: "destination",
                coordinate: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude),
                icon: Self.contextPinIcon,
                groundAnchor: CGPoint(x: 0.5, y: 1.0),
                zIndex: 8,
                title: dest.name
            ))
        }
        cachedMarkers = markers
    }

    private func beginRidingTransition(ref: String, candidate: BusRouteCandidate) {
        guard let detail = searchState.loadedDetail else { return }
        isKeypadVisible = false
        ridingActive = true
        if let coord = contextCoordinate {
            mapBox.view?.animate(to: GMSCameraPosition(target: coord, zoom: 15))
        }
        onStartRiding?(ref, candidate, detail)
    }

    // MARK: - Marker icons

    private static let contextPinIcon: UIImage = {
        let size: CGFloat = 36
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            UIColor.systemRed.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: size - 4, height: size - 4)).fill()
            let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let icon = UIImage(systemName: "flag.checkered", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(
                    x: (size - icon.size.width) / 2,
                    y: (size - icon.size.height) / 2
                ))
            }
        }
    }()

    // MARK: - Overlays

    @ViewBuilder
    private var mapOverlays: some View {
        if case .idle = searchState { emptyStateView }
        if searchState.isLoading { loadingOverlay }
    }

    // MARK: - Riding summary bar (乗車中フッター)

    private func ridingSummaryBar(detail: BusRouteDetail) -> some View {
        RouteMapSummaryBar(
            durationText: ridingDurationText ?? "—",
            distanceMeters: distanceToAlightingStop(detail: detail),
            showsDistance: true,
            fareText: ridingFareText,
            locale: locale
        )
    }

    private func distanceToAlightingStop(detail: BusRouteDetail) -> Double? {
        guard let coord = effectiveUserCoordinate else { return nil }
        // OSM ルートの最終停留所（降車位置）への直線距離
        let alightCoordinate: CLLocationCoordinate2D
        if let lastStop = detail.stops.last {
            alightCoordinate = lastStop.coordinate
        } else if let dest = destination {
            alightCoordinate = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
        } else {
            return nil
        }
        return GoogleRoutesAPIService.distanceMeters(
            fromLatitude: coord.latitude,
            fromLongitude: coord.longitude,
            toLatitude: alightCoordinate.latitude,
            toLongitude: alightCoordinate.longitude
        )
    }

    // MARK: - Route info bar

    private func routeInfoBar(detail: BusRouteDetail) -> some View {
        let lineLabel: String? = detail.candidate.directionLabel
            ?? (detail.candidate.name != detail.candidate.ref ? detail.candidate.name : nil)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(detail.candidate.ref)
                    .font(.subheadline.weight(.bold))
                if let label = lineLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if !detail.stops.isEmpty {
                Label("\(detail.stops.count)", systemImage: "bus.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            Text(AppLocaleString.text("路線図_OSM出典", locale: locale))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.large)
            if let ref = searchState.loadingRef {
                Text(AppLocaleString.formatted("路線図_読込中_%@", locale: locale, ref))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bus")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(AppLocaleString.text(
                contextCoordinate != nil ? "路線図_空状態_コンテキスト" : "路線図_空状態",
                locale: locale
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if contextCoordinate == nil {
                Label(
                    AppLocaleString.text("路線図_現在地なし警告", locale: locale),
                    systemImage: "location.slash"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Candidate sheet

    private var candidateSheet: some View {
        NavigationStack {
            List {
                if case .multipleCandidates(let list) = searchState {
                    Section {
                        ForEach(list) { candidate in
                            let candidateLabel: String? = candidate.directionLabel
                                ?? (candidate.name != candidate.ref ? candidate.name : nil)
                            Button {
                                showsCandidateSheet = false
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 200_000_000)
                                    loadRoute(candidate, collapseKeypad: true)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.ref)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let label = candidateLabel {
                                        Text(label)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(AppLocaleString.text("路線図_候補_ヒント", locale: locale))
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(AppLocaleString.text("路線図_候補", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if ridingActive, let detail = displayedRidingDetail {
            ToolbarItem(placement: .topBarLeading) {
                TransitBusLineBadgeLabel(text: detail.candidate.ref, isRidingBus: true)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isStaticText)
            }
            .hideSharedBackgroundIfAvailable()
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    if let detail = searchState.loadedDetail, !ridingActive {
                        Button {
                            beginRidingTransition(ref: detail.candidate.ref, candidate: detail.candidate)
                        } label: {
                            Image(systemName: "bus.fill")
                                .foregroundStyle(.green)
                        }
                        .accessibilityLabel(AppLocaleString.text("乗車開始", locale: locale))
                    }
                    if searchState.loadedDetail != nil, !ridingActive {
                        Button(action: clearRoute) {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(AppLocaleString.text("路線図_クリア", locale: locale))
                    }
                    if !ridingActive {
                        Button {
                            withAnimation(.spring(duration: 0.35)) { isKeypadVisible.toggle() }
                        } label: {
                            Image(systemName: isKeypadVisible ? "keyboard.chevron.compact.down" : "keyboard")
                        }
                        .accessibilityLabel(
                            AppLocaleString.text(
                                isKeypadVisible ? "テンキー_非表示" : "テンキー_表示",
                                locale: locale
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func releaseMapResources() {
        searchTask?.cancel()
        searchTask = nil
        searchState = .idle
        cachedPolylines = []
        cachedMarkers = []
        mapBox.view = nil
    }

    private func loadInitialRidingRouteIfNeeded() {
        guard isRidingMode, searchState.loadedDetail == nil, let candidate = initialRouteCandidate else { return }
        loadRoute(candidate)
    }

    private func startSearch() {
        let ref = routeNumberInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { return }

        guard let coord = contextCoordinate else {
            showError(OverpassError.noLocation.errorDescription ?? "")
            return
        }

        searchTask?.cancel()
        searchState = .searching

        searchTask = Task { @MainActor in
            do {
                let candidates = try await OverpassAPIService.searchCandidates(ref: ref, near: coord)
                guard !Task.isCancelled else { return }

                switch candidates.count {
                case 0:
                    showError(OverpassError.noResults.errorDescription ?? "")
                case 1:
                    loadRoute(candidates[0], collapseKeypad: true)
                default:
                    searchState = .multipleCandidates(candidates)
                    showsCandidateSheet = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                showError(AppLocaleString.userFacingError(error))
            }
        }
    }

    private func loadRoute(_ candidate: BusRouteCandidate, collapseKeypad: Bool = false) {
        searchTask?.cancel()
        searchState = .loadingRoute(candidate)

        searchTask = Task { @MainActor in
            do {
                let detail = try await OverpassAPIService.fetchRouteDetail(candidate)
                guard !Task.isCancelled else { return }
                searchState = .loaded(detail)
                rebuildMapLayers(from: detail)
                fitCamera(to: detail)
                if collapseKeypad {
                    isKeypadVisible = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                showError(AppLocaleString.userFacingError(error))
            }
        }
    }

    private func clearRoute() {
        searchTask?.cancel()
        searchTask = nil
        searchState = .idle
        cachedPolylines = []
        cachedMarkers = []
        routeNumberInput = ""
        if let coord = contextCoordinate {
            mapBox.view?.animate(to: GMSCameraPosition(target: coord, zoom: 13))
        }
    }

    private func fitCamera(to detail: BusRouteDetail) {
        var coords = detail.polylineSegments.flatMap { $0 }
        if let c = contextCoordinate { coords.append(c) }
        guard !coords.isEmpty else { return }

        var bounds = GMSCoordinateBounds()
        coords.forEach { bounds = bounds.includingCoordinate($0) }
        guard bounds.isValid else { return }
        mapBox.view?.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 50))
    }

    private func showError(_ message: String) {
        errorMessage = message
        showsError = true
        searchState = .idle
    }
}

#Preview {
    BusRouteMapView(
        currentLatitude: 21.0245,
        currentLongitude: 105.8412
    )
    .environment(\.locale, Locale(identifier: "ja"))
    .environmentObject(LocationService())
}
