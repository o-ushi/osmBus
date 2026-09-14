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
    /// 乗車開始を要求する。呼び出し元が実際に乗車を開始できた場合は true を返す想定
    /// （例: 既に別ルートで乗車中なら false を返し、この画面のローカル状態は乗車中へ遷移しない）。
    var onStartRiding: ((_ routeRef: String, _ candidate: BusRouteCandidate, _ detail: BusRouteDetail) -> Bool)? = nil
    /// バス番号バッジの長押し降車（乗換用）。トップ表の長押し降車と同じ経路を呼ぶ想定。
    var onEndRiding: (() -> Void)? = nil

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
    @State private var showsHistorySheet = false
    @State private var cachedPolylines: [GMapPolylineData] = []
    @State private var cachedMarkers: [GMapMarkerData] = []

    @EnvironmentObject private var locationService: LocationService

    init(
        currentLatitude: Double? = nil,
        currentLongitude: Double? = nil,
        destination: Destination? = nil,
        isRidingMode: Bool = false,
        initialRouteDetail: BusRouteDetail? = nil,
        initialRouteCandidate: BusRouteCandidate? = nil,
        ridingDurationText: String? = nil,
        onStartRiding: ((_ routeRef: String, _ candidate: BusRouteCandidate, _ detail: BusRouteDetail) -> Bool)? = nil,
        onEndRiding: (() -> Void)? = nil
    ) {
        self.currentLatitude = currentLatitude
        self.currentLongitude = currentLongitude
        self.destination = destination
        self.isRidingMode = isRidingMode
        self.initialRouteDetail = initialRouteDetail
        self.initialRouteCandidate = initialRouteCandidate
        self.ridingDurationText = ridingDurationText
        self.onStartRiding = onStartRiding
        self.onEndRiding = onEndRiding
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

    /// `LocationService.currentLocation` は測位済みなら常に最新値を保持するので、これを
    /// そのまま距離計算に使う。まだ一度も測位できていない最初の一瞬だけ、この地図を開いた
    /// 時点の位置 (`contextCoordinate`) にフォールバックする。
    private var effectiveUserCoordinate: CLLocationCoordinate2D? {
        locationService.currentLocation ?? contextCoordinate
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    GoogleMapView(
                        polylines: cachedPolylines,
                        markers: cachedMarkers,
                        shouldFollowUser: false,
                        myLocationIsRiding: ridingActive,
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
                                    endRiding()
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
                locationService.refreshCurrentFromCache()
            }
            .onDisappear(perform: releaseMapResources)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showsCandidateSheet, onDismiss: {
                if case .multipleCandidates = searchState { searchState = .idle }
            }) {
                candidateSheet
            }
            .sheet(isPresented: $showsHistorySheet) {
                BusRouteMapHistoryView(onSelect: loadFromHistory)
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
        guard onStartRiding?(ref, candidate, detail) == true else { return }
        isKeypadVisible = false
        ridingActive = true
        if let coord = contextCoordinate {
            mapBox.view?.animate(to: GMSCameraPosition(target: coord, zoom: 15))
        }
    }

    /// バス番号バッジの長押し。トップ表と同じく、未乗車なら乗車開始、この路線で乗車中なら降車（乗換用）。
    /// 別番号への乗換は、この画面には常に1路線しか読み込めない（乗車中は検索UIを隠している）ため発生しない。
    private func toggleRiding(detail: BusRouteDetail) {
        if ridingActive {
            endRiding()
        } else {
            beginRidingTransition(ref: detail.candidate.ref, candidate: detail.candidate)
        }
    }

    /// 乗車中に他の操作（削除／履歴選択／別番号検索、長押し降車も含む）をしたら自動的に降車する。
    /// 今の画面（この BusRouteMapView）は維持し、呼び出し元へは戻らない。
    private func endRiding() {
        guard ridingActive else { return }
        ridingActive = false
        onEndRiding?()
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
            // 目的地未設定のときの最終停留所までの距離は、ユーザーの行き先ではなくナビとして
            // 意味が薄いため出さない（Step 1: 目的地なしは「あと」に載せない）。
            showsDistance: destination != nil,
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
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 4) {
                if let detail = ridingActive ? displayedRidingDetail : searchState.loadedDetail {
                    busNumberBadge(detail: detail)
                }
                if searchState.loadedDetail != nil {
                    Button {
                        endRiding()
                        clearRoute()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(AppLocaleString.text("路線図_クリア", locale: locale))
                }
                if ThirdPartyDataConsent.isGranted {
                    Button {
                        showsHistorySheet = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(AppLocaleString.text("路線図_履歴", locale: locale))
                }

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

    /// ロード中の路線のバス番号バッジ。タップでは何もしない（誤乗車防止）。
    /// 長押しで乗車開始／降車をトグルする（トップのバス番号表と同じ思想）。
    private func busNumberBadge(detail: BusRouteDetail) -> some View {
        TransitBusLineBadgeLabel(text: detail.candidate.ref, isRidingBus: ridingActive)
            .onLongPressGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                toggleRiding(detail: detail)
            }
            .accessibilityLabel(detail.candidate.ref)
            .accessibilityHint(AppLocaleString.text("路線図_乗降ヒント", locale: locale))
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

        // 乗車中に別の番号を検索したら、その番号への乗り換え扱いではなく自動的に降車する。
        endRiding()

        searchTask?.cancel()

        // すでに履歴一覧（BusLineMapStore）に同じ番号の路線があれば、Overpass への再検索なしでそれを表示する。
        if ThirdPartyDataConsent.isGranted {
            let cachedMatches = BusLineMapStore.details(matching: ref)
            switch cachedMatches.count {
            case 0:
                break
            case 1:
                let match = cachedMatches[0]
                BusLineMapStore.touch(relationId: match.candidate.id)
                applyLoadedRoute(match, collapseKeypad: true)
                return
            default:
                searchState = .multipleCandidates(cachedMatches.map(\.candidate))
                showsCandidateSheet = true
                return
            }
        }

        guard let coord = contextCoordinate else {
            showError(OverpassError.noLocation.errorDescription ?? "")
            return
        }

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

        // 一覧に既にあるバス（同じ relationId）ならキャッシュからそのまま表示し、再取得しない。
        if let cached = BusLineMapStore.detail(forRelationId: candidate.id) {
            BusLineMapStore.touch(relationId: candidate.id)
            applyLoadedRoute(cached, collapseKeypad: collapseKeypad)
            return
        }

        searchState = .loadingRoute(candidate)

        searchTask = Task { @MainActor in
            do {
                let detail = try await OverpassAPIService.fetchRouteDetail(candidate)
                guard !Task.isCancelled else { return }
                BusLineMapStore.remember(detail)
                applyLoadedRoute(detail, collapseKeypad: collapseKeypad)
            } catch {
                guard !Task.isCancelled else { return }
                showError(AppLocaleString.userFacingError(error))
            }
        }
    }

    /// 履歴一覧からの選択。キャッシュ済みの `BusRouteDetail` をそのまま地図に載せる（再取得なし）。
    private func loadFromHistory(_ detail: BusRouteDetail) {
        // 乗車中に履歴から別の路線を選んだら、自動的に降車してから切り替える。
        endRiding()
        searchTask?.cancel()
        searchTask = nil
        routeNumberInput = ""
        clearsOnNextInput = false
        BusLineMapStore.touch(relationId: detail.candidate.id)
        applyLoadedRoute(detail, collapseKeypad: true)
    }

    /// 検索結果・履歴・キャッシュのいずれから来ても、地図への反映はここに統一する。
    private func applyLoadedRoute(_ detail: BusRouteDetail, collapseKeypad: Bool) {
        searchState = .loaded(detail)
        rebuildMapLayers(from: detail)
        fitCamera(to: detail)
        if collapseKeypad {
            isKeypadVisible = false
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
