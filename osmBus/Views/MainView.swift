import CoreLocation
import SwiftUI
import UIKit

struct MainView: View {
    @Binding var pendingDeepLinkDestination: Destination?

    @State private var viewModel = MainViewModel()
    @StateObject private var locationService = LocationService()
    @State private var showsSettings = false
    @State private var opensAPISettingsOnLaunch = false
    @State private var showsDestinationSheet = false
    @State private var showsSavedPlacesSheet = false
    @State private var showsMoreActions = false
    @State private var showsPlanManagement = false
    @State private var showsHelp = false
    @State private var showsHistorySheet = false
    @State private var showsTransitRoutesSheet = false
    @State private var boardingRouteMapSheet: BoardingRouteMapSheetModel?
@State private var showsMapLocationPicker = false
    @State private var mapPickerInitialRole: MapPickRole = .destination
    @State private var busRouteMapPresentation: BusRouteMapPresentation?
    @State private var pendingOSMRidingStart: (routeRef: String, candidate: BusRouteCandidate, detail: BusRouteDetail)?
    @State private var showsWrongDirectionAlert = false
    @State private var presentedRidingAlert: ActiveRidingAlert?
    @State private var showsRouteDatabaseResetConfirm = false
    @State private var showsRidingBusCandidateSheet = false
    @State private var ridingBusCandidates: [String] = []
    @State private var isOnboardingRideSelection = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SharedRoutesTrialStore.self) private var trialStore
    @State private var showsTrialExhaustedAlert = false

    private var canUseRoutesAPI: Bool {
        GoogleRoutesAPIKeyStore.isConfigured
    }

    private var showsTrialRemainingLabel: Bool {
        !GoogleRoutesAPIKeyStore.hasUserConfiguredKey && trialStore.isUsingSharedTrialKey
    }

    private var showsAPIKeyPrompt: Bool {
        !canUseRoutesAPI
    }

    private var isTrialExhaustedWithoutUserKey: Bool {
        !GoogleRoutesAPIKeyStore.hasUserConfiguredKey && trialStore.isTrialExhausted
            && !Secrets.sharedGoogleRoutesAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sceneColor: Color {
        AppTheme.sceneColor(for: colorScheme)
    }

    private var sceneTint: Color {
        AppTheme.accent
    }

    private var destinationLabel: String {
        viewModel.destination?.name ?? AppLocaleString.text("目的地を設定", locale: locale)
    }

    private var currentLocationStatusText: String {
        if let manualName = viewModel.manualOriginName {
            return manualName
        }
        if locationService.isDenied {
            return locationService.lastError
                ?? AppLocaleString.text("位置情報の利用が許可されていません。設定から許可してください。", locale: locale)
        }
        if locationService.isUpdating {
            return AppLocaleString.text("取得中…", locale: locale)
        }
        if viewModel.hasCurrentLocation {
            return AppLocaleString.text("取得済み", locale: locale)
        }
        return locationService.lastError ?? AppLocaleString.text("未取得", locale: locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SceneBackgroundLayer(
                    colorScheme: colorScheme,
                    sceneColor: sceneColor
                )
                .ignoresSafeArea()

                GeometryReader { geometry in
                    let isZoomedCompact = KeypadMetrics.isZoomedCompact(screenHeight: geometry.size.height)
                    let halfHeight = geometry.size.height / 2
                    let sectionSpacing = isZoomedCompact ? 8.0 : 12.0

                    VStack(spacing: 0) {
                        topHalf(
                            height: halfHeight,
                            sectionSpacing: sectionSpacing,
                            isZoomedCompact: isZoomedCompact
                        )

                        BusKeypadView(
                            busNumber: viewModel.enteredBusNumber,
                            canSubmit: !viewModel.enteredBusNumber.isEmpty,
                            onCharacter: { viewModel.appendBusCharacter($0) },
                            onSubmit: {
                                if viewModel.ridingState != nil {
                                    let candidates = viewModel.ridingBusCandidates(for: viewModel.enteredBusNumber)
                                    ridingBusCandidates = candidates
                                    showsRidingBusCandidateSheet = true
                                } else {
                                    viewModel.submitBusCheck()
                                }
                            },
                            onClear: {
                                viewModel.clearBusNumber()
                            }
                        )
                        .environment(\.mainScreenCompactLayout, isZoomedCompact)
                        .padding(.horizontal, AppTheme.screenPadding)
                        .padding(.bottom, isZoomedCompact ? 6 : 8)
                        .frame(height: halfHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .busMainScreenStyled()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.ridingState != nil {
                        Button {
                            Task { @MainActor in
                                await Task.yield()
                                openRidingRouteMap()
                            }
                        } label: {
                            Label(
                                AppLocaleString.text("乗車中", locale: locale),
                                systemImage: "bus.fill"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
                if showsTrialRemainingLabel {
                    ToolbarItem(placement: .principal) {
                        Text(
                            AppLocaleString.formatted(
                                "お試し残り_%d",
                                locale: locale,
                                trialStore.remainingTrialCount
                            )
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(sceneTint.opacity(0.88))
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if viewModel.isOSMMapRiding, viewModel.osmRidingRouteCandidate != nil {
                            openOSMRidingRouteMap()
                        } else {
                            openBrowseRouteMap()
                        }
                    } label: {
                        Image(systemName: "map")
                            .foregroundStyle(sceneTint)
                    }
                    .accessibilityLabel(AppLocaleString.text("路線図", locale: locale))

                    moreMenu
                }
            }
            .sheet(isPresented: $showsSettings) {
                AppSettingsView(opensAPISettingsOnAppear: opensAPISettingsOnLaunch)
                    .environment(\.locale, locale)
                    .presentationDragIndicator(.visible)
                    .onDisappear {
                        opensAPISettingsOnLaunch = false
                        trialStore.refresh()
                        if viewModel.ridingState == nil {
                            viewModel.refreshBusCheck(userInitiated: false)
                            viewModel.refreshTransitRoutes()
                        }
                    }
            }
            .sheet(isPresented: $showsPlanManagement) {
                PlanManagementView()
                    .environment(\.locale, locale)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsHelp) {
                HelpView()
                    .environment(\.locale, locale)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsDestinationSheet) {
                DestinationInputView(
                    currentDestination: viewModel.destination,
                    onSelect: { viewModel.setDestination($0) },
                    onClear: { viewModel.clearDestination() }
                )
                .environment(\.locale, locale)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsSavedPlacesSheet) {
                SavedPlacesView(
                    currentDestination: viewModel.destination,
                    onSelectDestination: { viewModel.setDestination($0) }
                )
                .environment(\.locale, locale)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsHistorySheet) {
                DestinationHistoryView(
                    currentDestination: viewModel.destination,
                    onSelectDestination: { viewModel.setDestination($0) }
                )
                .environment(\.locale, locale)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsTransitRoutesSheet) {
                TransitRoutesSheetView(
                    destinationName: viewModel.destination?.name ?? "",
                    destination: viewModel.destination,
                    originLatitude: viewModel.effectiveOriginLatitude,
                    originLongitude: viewModel.effectiveOriginLongitude,
                    loadState: viewModel.transitRoutesLoadState,
                    routes: viewModel.accumulatedTransitRoutes,
                    ridingBusNumber: viewModel.ridingState?.busNumber,
                    onReload: { viewModel.refreshTransitRoutes(userInitiated: true) },
                    onSwitchRoute: { newIndex in
                        viewModel.switchBoardingRoute(to: newIndex)
                    },
                    onSelectRidingBus: { routeIndex, busNumber in
                        handleRidingBusLongPress(busNumber: busNumber) {
                            viewModel.startRidingForBusSelection(routeIndex: routeIndex, busNumber: busNumber)
                        }
                    }
                )
                .environment(\.locale, locale)
            }
            .sheet(item: $boardingRouteMapSheet) { sheet in
                BoardingRouteMapCover(
                    sheet: sheet,
                    onSwitchRoute: { newIndex in
                        viewModel.switchBoardingRoute(to: newIndex)
                    },
                    onLoadRouteOptions: {
                        viewModel.accumulatedTransitRoutes
                    },
                    onSelectRidingBus: { routeIndex, busNumber in
                        handleRidingBusLongPress(busNumber: busNumber) {
                            viewModel.startRidingForBusSelection(routeIndex: routeIndex, busNumber: busNumber)
                            presentBoardingRouteMapSheet()
                        }
                    }
                )
                // 乗車中バスの切り替え時、地図のキャッシュ済みポリライン・ピンを
                // 作り直させるため、乗車バス番号が変わったら別ビューとして再生成する。
                .id("\(sheet.id)-\(sheet.ridingBusNumber ?? "")")
                .environment(\.locale, locale)
                .environment(SharedMapsTrialStore.shared)
            }
            .sheet(isPresented: $showsMapLocationPicker) {
                MapLocationPickerView(
                    initialRole: mapPickerInitialRole,
                    onPickOrigin: { lat, lon, name in
                        viewModel.setManualOrigin(latitude: lat, longitude: lon, name: name)
                    },
                    onPickDestination: { destination in
                        viewModel.setDestination(destination)
                    }
                )
                .environment(\.locale, locale)
            }
            .sheet(item: $busRouteMapPresentation, onDismiss: applyPendingOSMRidingStartIfNeeded) { presentation in
                BusRouteMapCover(
                    presentation: presentation,
                    onStartRiding: { routeRef, candidate, detail in
                        pendingOSMRidingStart = (routeRef, candidate, detail)
                    }
                )
                .environment(\.locale, locale)
                .environment(SharedMapsTrialStore.shared)
            }
            .onShake(perform: openBoardingRouteMapFromShake)
            .onAppear {
                locationService.refreshCurrentFromCache()
                viewModel.updateCurrentLocation(locationService.currentLocation)
                locationService.fetchCurrentLocation()
                syncContinuousLocationTracking()
                applyPendingDeepLinkIfNeeded()
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: pendingDeepLinkDestination) { _, _ in
                applyPendingDeepLinkIfNeeded()
            }
            .onChange(of: locationService.currentLocation?.latitude) { _, _ in
                guard let coordinate = locationService.currentLocation else { return }
                updateAdaptiveLocationAccuracy(current: coordinate)
                // 乗車進捗チェックはシートの有無に関わらず常に実行
                viewModel.checkRidingProgress(at: coordinate)
                // 地図シート・経路一覧シート表示中は viewModel 更新を止め、re-render ループを防ぐ
                guard busRouteMapPresentation == nil,
                      boardingRouteMapSheet == nil,
                      !showsTransitRoutesSheet else { return }

                viewModel.updateCurrentLocation(locationService.currentLocation)
                // 乗車中はバス判定・経路更新の頻繁なリフレッシュを止める
                if viewModel.ridingState == nil {
                    viewModel.refreshBusCheck(userInitiated: false)
                    viewModel.refreshTransitRoutes()
                }
            }
            .onChange(of: continuousLocationTrackingKey) { _, _ in
                syncContinuousLocationTracking()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                locationService.fetchCurrentLocation()
                if viewModel.ridingState == nil {
                    viewModel.refreshBusCheck(userInitiated: false)
                    viewModel.refreshTransitRoutes()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .osmBusDataDeleted)) { _ in
                viewModel.clearDestination()
            }
            .onChange(of: viewModel.destination?.id) { _, _ in
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: viewModel.resultState) { _, newState in
                guard case .trialExhausted = newState else { return }
                showsTrialExhaustedAlert = true
            }
            .onChange(of: viewModel.wrongDirectionDetected) { _, detected in
                if detected { showsWrongDirectionAlert = true }
            }
            .onChange(of: viewModel.activeRidingAlert?.id) { _, _ in
                presentedRidingAlert = viewModel.activeRidingAlert
            }
            .alert(item: $presentedRidingAlert) { alert in
                Alert(
                    title: Text(ridingAlertTitle(for: alert.kind, locale: locale)),
                    message: Text(ridingAlertMessage(for: alert.kind, locale: locale)),
                    dismissButton: .cancel(Text(AppLocaleString.text("OK", locale: locale))) {
                        viewModel.dismissActiveRidingAlert()
                    }
                )
            }
            .alert(
                AppLocaleString.text("逆方向_タイトル", locale: locale),
                isPresented: $showsWrongDirectionAlert
            ) {
                Button(AppLocaleString.text("OK", locale: locale), role: .cancel) {
                    viewModel.dismissWrongDirection()
                }
            } message: {
                Text(AppLocaleString.text(
                    viewModel.isOSMMapRiding ? "逆方向_本文_次で降車" : "逆方向_本文",
                    locale: locale
                ))
            }
            .alert(
                AppLocaleString.text("路線候補_初期化確認", locale: locale),
                isPresented: $showsRouteDatabaseResetConfirm
            ) {
                Button(AppLocaleString.text("はい", locale: locale)) {
                    viewModel.resetAccumulatedTransitRoutes()
                    locationService.fetchCurrentLocation()
                }
                Button(AppLocaleString.text("いいえ", locale: locale), role: .cancel) {
                    locationService.fetchCurrentLocation()
                }
            }
            .alert(
                AppLocaleString.text("お試し枠_使い切り_タイトル", locale: locale),
                isPresented: $showsTrialExhaustedAlert
            ) {
                Button(AppLocaleString.text("お試し枠_設定を開く", locale: locale)) {
                    opensAPISettingsOnLaunch = true
                    showsSettings = true
                }
                Button(AppLocaleString.text("OK", locale: locale), role: .cancel) {}
            } message: {
                Text(AppLocaleString.text("お試し枠_使い切り_説明", locale: locale))
            }
            .confirmationDialog(
                AppLocaleString.text("乗車中バス_設定タイトル", locale: locale),
                isPresented: $showsRidingBusCandidateSheet,
                titleVisibility: .visible
            ) {
                ForEach(ridingBusCandidates, id: \.self) { candidate in
                    Button(candidate) {
                        if isOnboardingRideSelection {
                            viewModel.startRidingOnboarding(busNumber: candidate)
                            isOnboardingRideSelection = false
                        } else {
                            viewModel.overrideRidingBusNumber(candidate)
                        }
                    }
                }
                Button(AppLocaleString.text("キャンセル", locale: locale), role: .cancel) {
                    isOnboardingRideSelection = false
                }
            }
        }
        .environmentObject(locationService)
        .tint(sceneTint)
    }

    private func syncContinuousLocationTracking() {
        let needsTracking = viewModel.shouldTrackRiding
            || boardingRouteMapSheet != nil
            || busRouteMapPresentation != nil
        if needsTracking {
            // 乗車中は画面を見ていなくても距離アラートを続ける必要があるためバックグラウンド追跡を許可する。
            // 地図を眺めているだけの間は前面のみで十分なので iOS の自動休止に任せる。
            // ただし一番近い到着アラートが鳴った後は、降車ボタンの押し忘れで
            // バックグラウンド測位が延々と続き端末が発熱するのを避けるため、
            // 常時ONを自動的に解除する(乗車状態自体は降車ボタンを押すまで継続)。
            let allowsBackground = viewModel.shouldTrackRiding && !viewModel.ridingNearestAlertReached
            locationService.startContinuousTracking(allowsBackground: allowsBackground)
        } else if viewModel.ridingState == nil {
            locationService.stopContinuousTrackingAndDisableBackground()
        }
    }

    private func updateAdaptiveLocationAccuracy(current: CLLocationCoordinate2D) {
        let target: (latitude: Double, longitude: Double)?
        if let alight = viewModel.ridingAlightCoordinate {
            target = (alight.latitude, alight.longitude)
        } else if let destination = viewModel.destination {
            target = (destination.latitude, destination.longitude)
        } else {
            target = nil
        }
        let distance = target.map {
            GoogleRoutesAPIService.distanceMeters(
                fromLatitude: current.latitude,
                fromLongitude: current.longitude,
                toLatitude: $0.latitude,
                toLongitude: $0.longitude
            )
        }
        locationService.updateAccuracy(distanceToTargetMeters: distance)
    }

    private var continuousLocationTrackingKey: String {
        [
            viewModel.shouldTrackRiding ? "1" : "0",
            viewModel.ridingNearestAlertReached ? "1" : "0",
            boardingRouteMapSheet.map { String($0.id) } ?? "",
            busRouteMapPresentation?.id.uuidString ?? ""
        ].joined(separator: "|")
    }

    private func ridingAlertTitle(for kind: ActiveRidingAlert.Kind, locale: Locale) -> String {
        switch kind {
        case .distance:
            return AppLocaleString.text("距離アラート_タイトル", locale: locale)
        }
    }

    private func ridingAlertMessage(for kind: ActiveRidingAlert.Kind, locale: Locale) -> String {
        switch kind {
        case .distance(let meters):
            return AppLocaleString.formatted("距離アラート_%d", locale: locale, meters)
        }
    }

    @ViewBuilder
    private func topHalf(height: CGFloat, sectionSpacing: CGFloat, isZoomedCompact: Bool) -> some View {
        VStack(spacing: sectionSpacing) {
            if showsAPIKeyPrompt {
                APIKeySetupBanner(isTrialExhausted: isTrialExhaustedWithoutUserKey) {
                    opensAPISettingsOnLaunch = true
                    showsSettings = true
                }
            }

            DestinationBarView(
                label: destinationLabel,
                hasDestination: viewModel.hasDestination,
                isDisabled: viewModel.ridingState != nil,
                onTap: { showsDestinationSheet = true },
                onMapPick: {
                    mapPickerInitialRole = .destination
                    showsMapLocationPicker = true
                }
            )
            .frame(maxHeight: .infinity)

            CurrentLocationBarView(
                statusText: currentLocationStatusText,
                isUpdating: locationService.isUpdating,
                showsSettingsAction: locationService.isDenied,
                hasManualOrigin: viewModel.hasManualOrigin,
                isDisabled: viewModel.ridingState != nil,
                onRefresh: { handleCurrentLocationRefreshTap() },
                onOpenSettings: openAppSettings,
                onClearManualOrigin: { viewModel.clearManualOrigin() },
                onMapPick: {
                    mapPickerInitialRole = .origin
                    showsMapLocationPicker = true
                }
            )
            .frame(maxHeight: .infinity)

            if viewModel.hasDestination && canUseRoutesAPI {
                transitRoutesAccessButton
                    .frame(maxHeight: .infinity)
            }

            ResultBannerView(
                state: viewModel.resultState,
                busNumber: viewModel.enteredBusNumber,
                onRetry: viewModel.enteredBusNumber.isEmpty ? nil : {
                    viewModel.refreshBusCheck()
                },
                onStartRiding: {
                    beginRidingOnboarding(for: viewModel.resolvedBoardingBusRef())
                },
                onStartRidingWithVariant: { variantName in
                    beginRidingOnboarding(for: variantName)
                },
                isBoardingRouteCheapest: viewModel.isBoardingRouteCheapest,
                isRiding: viewModel.ridingState != nil,
                onStopRiding: viewModel.ridingState != nil ? {
                    viewModel.clearBusNumber()
                } : nil,
                otherBoardableVariants: viewModel.otherBoardableVariants
            )
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.top, isZoomedCompact ? 4 : 6)
        .padding(.bottom, isZoomedCompact ? 4 : 6)
        .frame(height: height)
        .environment(\.mainScreenCompactLayout, isZoomedCompact)
    }

    private var transitRoutesAccessButton: some View {
        Button {
            viewModel.refreshTransitRoutes(userInitiated: true)
            showsTransitRoutesSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocaleString.text("経路を見る", locale: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(transitRoutesSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.cardPaddingH)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(BusCardBackground())
        }
        .buttonStyle(.plain)
    }

    private var transitRoutesSubtitle: String {
        switch viewModel.transitRoutesLoadState {
        case .idle, .loading:
            return AppLocaleString.text("経路読込中", locale: locale)
        case .loaded:
            return AppLocaleString.formatted(
                "経路件数_%d",
                locale: locale,
                viewModel.accumulatedTransitRoutes.count
            )
        case .failed:
            return AppLocaleString.text("経路取得失敗", locale: locale)
        }
    }

    private func applyPendingDeepLinkIfNeeded() {
        guard let destination = pendingDeepLinkDestination else { return }
        viewModel.setDestination(destination)
        pendingDeepLinkDestination = nil
        viewModel.refreshTransitRoutes(userInitiated: true)
        showsTransitRoutesSheet = true
    }

    private var moreMenu: some View {
        Button {
            showsMoreActions = true
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(sceneTint)
        }
        .popover(isPresented: $showsMoreActions, arrowEdge: .top) {
            MoreActionsMenuView(
                onHistory: { performMoreAction { showsHistorySheet = true } },
                onRegisterPlace: { performMoreAction { showsSavedPlacesSheet = true } },
                onSettings: { performMoreAction { showsSettings = true } },
                onPlanManagement: { performMoreAction { showsPlanManagement = true } },
                onHelp: { performMoreAction { showsHelp = true } }
            )
            .environment(\.locale, locale)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(AppLocaleString.text("その他", locale: locale))
    }

    private func performMoreAction(_ action: @escaping () -> Void) {
        showsMoreActions = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            action()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func handleCurrentLocationRefreshTap() {
        guard viewModel.hasAccumulatedTransitRoutes else {
            locationService.fetchCurrentLocation()
            return
        }
        showsRouteDatabaseResetConfirm = true
    }

    private func applyPendingOSMRidingStartIfNeeded() {
        guard let pending = pendingOSMRidingStart else { return }
        pendingOSMRidingStart = nil
        viewModel.startRidingFromOSMMap(
            routeRef: pending.routeRef,
            candidate: pending.candidate,
            routeDetail: pending.detail
        )
    }

    private func beginRidingOnboarding(for busNumber: String) {
        let candidates = viewModel.ridingBusCandidates(for: busNumber)
        guard candidates.count > 1 else {
            viewModel.startRidingOnboarding(busNumber: candidates.first ?? busNumber)
            return
        }
        ridingBusCandidates = candidates
        isOnboardingRideSelection = true
        showsRidingBusCandidateSheet = true
    }

    private func handleRidingBusLongPress(busNumber: String, otherwise selectRidingBus: () -> Void) {
        if let currentBusNumber = viewModel.ridingState?.busNumber,
           currentBusNumber.uppercased() == busNumber.uppercased() {
            viewModel.clearBusNumber()
        } else {
            selectRidingBus()
        }
    }

    private func openBrowseRouteMap() {
        busRouteMapPresentation = BusRouteMapPresentation(
            latitude: viewModel.effectiveOriginLatitude,
            longitude: viewModel.effectiveOriginLongitude,
            destination: viewModel.destination,
            mode: .browse
        )
    }

    @discardableResult
    private func presentBoardingRouteMapSheet() -> Bool {
        if viewModel.isOSMMapRiding, viewModel.osmRidingRouteCandidate != nil {
            openOSMRidingRouteMap()
            return true
        }
        guard let index = viewModel.boardingRouteIndex,
              let route = viewModel.boardingRoute,
              let destination = viewModel.destination,
              let originLatitude = viewModel.effectiveOriginLatitude,
              let originLongitude = viewModel.effectiveOriginLongitude else { return false }
        let ridingAlight = viewModel.ridingAlightCoordinate.map {
            RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        boardingRouteMapSheet = BoardingRouteMapSheetModel(
            id: index,
            route: route,
            origin: RouteCoordinate(latitude: originLatitude, longitude: originLongitude),
            destination: destination,
            routeOptionCount: viewModel.accumulatedTransitRoutes.count,
            ridingBusNumber: viewModel.ridingState?.busNumber,
            ridingAlightCoordinate: ridingAlight
        )
        return true
    }

    private func openOSMRidingRouteMap() {
        guard let candidate = viewModel.osmRidingRouteCandidate else { return }
        busRouteMapPresentation = BusRouteMapPresentation(
            latitude: viewModel.effectiveOriginLatitude,
            longitude: viewModel.effectiveOriginLongitude,
            destination: viewModel.destination,
            mode: .riding(candidate, cachedDetail: viewModel.osmRidingRouteDetail),
            ridingDurationText: viewModel.boardingRoute.map {
                GoogleRoutesAPIService.displayDuration(for: $0, locale: locale)
            },
            ridingFareText: viewModel.boardingRoute.flatMap {
                GoogleRoutesAPIService.displayFare(for: $0)
            }
        )
    }

    private func openRidingRouteMap() {
        if viewModel.isOSMMapRiding, viewModel.osmRidingRouteCandidate != nil {
            openOSMRidingRouteMap()
            return
        }
        guard presentBoardingRouteMapSheet() else { return }
    }

    private func openBoardingRouteMapFromShake() {
        guard viewModel.hasDestination, canUseRoutesAPI else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        viewModel.refreshTransitRoutes(userInitiated: true)
        showsTransitRoutesSheet = true
    }
}

private struct BusRouteMapCover: View {
    let presentation: BusRouteMapPresentation
    let onStartRiding: (String, BusRouteCandidate, BusRouteDetail) -> Void

    var body: some View {
        BusRouteMapSheet(
            presentation: presentation,
            onStartRiding: onStartRiding
        )
    }
}

private struct BoardingRouteMapCover: View {
    let sheet: BoardingRouteMapSheetModel
    let onSwitchRoute: (Int) -> Void
    let onLoadRouteOptions: () -> [ParsedTransitRoute]
    let onSelectRidingBus: (Int, String) -> Void

    var body: some View {
        TransitRouteMapView(
            routeIndex: sheet.id,
            route: sheet.route,
            origin: sheet.origin,
            destination: sheet.destination,
            ridingBusNumber: sheet.ridingBusNumber,
            ridingAlightCoordinate: sheet.ridingAlightCoordinate,
            routeOptionCount: sheet.routeOptionCount,
            onLoadRouteOptions: onLoadRouteOptions,
            onSwitchRoute: onSwitchRoute,
            onSelectRidingBus: onSelectRidingBus
        )
    }
}

private struct BusRouteMapSheet: View {
    let presentation: BusRouteMapPresentation
    let onStartRiding: (String, BusRouteCandidate, BusRouteDetail) -> Void

    var body: some View {
        switch presentation.mode {
        case .browse:
            BusRouteMapView(
                currentLatitude: presentation.latitude,
                currentLongitude: presentation.longitude,
                destination: presentation.destination,
                onStartRiding: onStartRiding
            )
        case .riding(let candidate, let cachedDetail):
            BusRouteMapView(
                currentLatitude: presentation.latitude,
                currentLongitude: presentation.longitude,
                destination: presentation.destination,
                isRidingMode: true,
                initialRouteDetail: cachedDetail,
                initialRouteCandidate: cachedDetail == nil ? candidate : nil,
                ridingDurationText: presentation.ridingDurationText,
                ridingFareText: presentation.ridingFareText
            )
        }
    }
}

private struct BusRouteMapPresentation: Identifiable {
    enum Mode {
        case browse
        case riding(BusRouteCandidate, cachedDetail: BusRouteDetail?)
    }

    let id = UUID()
    let latitude: Double?
    let longitude: Double?
    let destination: Destination?
    let mode: Mode
    var ridingDurationText: String? = nil
    var ridingFareText: String? = nil
}

private struct DeviceShakeView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> DeviceShakeViewController {
        DeviceShakeViewController(onShake: onShake)
    }

    func updateUIViewController(_ uiViewController: DeviceShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

private final class DeviceShakeViewController: UIViewController {
    var onShake: () -> Void

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        onShake()
    }
}

private extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        background(DeviceShakeView(onShake: action))
    }
}

#Preview {
    MainView(pendingDeepLinkDestination: .constant(nil))
        .environment(\.locale, Locale(identifier: "ja"))
        .environment(SharedRoutesTrialStore.shared)
}
