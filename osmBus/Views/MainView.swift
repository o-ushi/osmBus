import CoreLocation
import SwiftUI
import UIKit

struct MainView: View {
    @Binding var pendingDeepLinkDestination: Destination?

    @State private var viewModel: MainViewModel
    @StateObject private var locationService: LocationService
    /// 既定表示はトップ画面。false でメイン画面（キーパッド判定 UI）を表示する。
    @State private var showsTopScreen = true
    @State private var showsSettings = false
    @State private var opensAPISettingsOnLaunch = false
    @State private var showsDestinationSheet = false
    @State private var showsOriginSearchSheet = false
    @State private var showsMoreActions = false
    @State private var showsPlanManagement = false
    @State private var showsHelp = false
    @State private var boardingRouteMapSheet: BoardingRouteMapSheetModel?
    @State private var topBusRouteMapSelection: TransitRouteMapSelection?
@State private var showsMapLocationPicker = false
    @State private var mapPickerInitialRole: MapPickRole = .destination
    @State private var busRouteMapPresentation: BusRouteMapPresentation?
    @State private var showsWrongDirectionAlert = false
    @State private var presentedRidingAlert: ActiveRidingAlert?
    @State private var showsRouteDatabaseResetConfirm = false
    @State private var showsCancelNavigationConfirm = false
    @State private var showsRidingBusCandidateSheet = false
    @State private var ridingBusCandidates: [String] = []
    @State private var isOnboardingRideSelection = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.busCardStyle) private var cardStyle
    @Environment(SharedRoutesTrialStore.self) private var trialStore
    @State private var showsTrialExhaustedAlert = false

    init(pendingDeepLinkDestination: Binding<Destination?>) {
        _pendingDeepLinkDestination = pendingDeepLinkDestination
        let service = LocationService()
        _locationService = StateObject(wrappedValue: service)
        _viewModel = State(wrappedValue: MainViewModel(locationService: service))
    }

    private var canUseRoutesAPI: Bool {
        GoogleRoutesAPIKeyStore.isConfigured
    }

    private var showsTrialRemainingLabel: Bool {
        !trialStore.hasUserConfiguredKey && trialStore.isUsingSharedTrialKey
    }

    private var showsAPIKeyPrompt: Bool {
        !canUseRoutesAPI
    }

    private var isTrialExhaustedWithoutUserKey: Bool {
        !trialStore.hasUserConfiguredKey && trialStore.isTrialExhausted
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

    /// 出発地検索シートの「現在の出発地」欄に出す。手動出発地が無ければ nil (GPS 使用中)。
    private var manualOriginAsDestination: Destination? {
        guard let lat = viewModel.manualOriginLatitude,
              let lon = viewModel.manualOriginLongitude,
              let name = viewModel.manualOriginName else { return nil }
        return Destination(name: name, subtitle: nil, latitude: lat, longitude: lon)
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

    @ViewBuilder
    private var screenContent: some View {
        ZStack {
            SceneBackgroundLayer(
                colorScheme: colorScheme,
                sceneColor: sceneColor
            )
            .ignoresSafeArea()

            if showsTopScreen {
                TopScreenView(
                    destinationLabel: destinationLabel,
                    hasDestination: viewModel.hasDestination,
                    currentLocationStatusText: currentLocationStatusText,
                    isUpdatingCurrentLocation: locationService.isUpdating,
                    showsLocationSettingsAction: locationService.isDenied,
                    hasManualOrigin: viewModel.hasManualOrigin,
                    isInputDisabled: viewModel.ridingState != nil,
                    accumulatedTransitRoutes: viewModel.accumulatedTransitRoutes,
                    transitRoutesLoadState: viewModel.transitRoutesLoadState,
                    ridingBusNumber: viewModel.ridingState?.busNumber,
                    originLatitude: viewModel.effectiveOriginLatitude,
                    originLongitude: viewModel.effectiveOriginLongitude,
                    destinationLatitude: viewModel.destination?.latitude,
                    destinationLongitude: viewModel.destination?.longitude,
                    trialRemainingText: showsTrialRemainingLabel
                        ? AppLocaleString.formatted(
                            "お試し残り_%d",
                            locale: locale,
                            trialStore.remainingTrialCount
                        )
                        : nil,
                    onDestinationTap: { showsDestinationSheet = true },
                    onDestinationMapPick: {
                        mapPickerInitialRole = .destination
                        showsMapLocationPicker = true
                    },
                    onCurrentLocationRefresh: { handleCurrentLocationRefreshTap() },
                    onOpenLocationSettings: openAppSettings,
                    onClearManualOrigin: { viewModel.clearManualOrigin() },
                    onCurrentLocationMapPick: {
                        mapPickerInitialRole = .origin
                        showsMapLocationPicker = true
                    },
                    onCurrentLocationTap: { showsOriginSearchSheet = true },
                    onReloadTransitRoutes: { viewModel.refreshTransitRoutes(userInitiated: true) },
                    onTapBusNumber: { handleTopBusNumberTap(routeIndex: $0, busNumber: $1) },
                    onLongPressBusNumber: { handleTopBusNumberLongPress(routeIndex: $0, busNumber: $1) }
                )
            } else {
                mainScreenContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !showsTopScreen, showsTrialRemainingLabel {
                TrialRemainingLabel(
                    text: AppLocaleString.formatted(
                        "お試し残り_%d",
                        locale: locale,
                        trialStore.remainingTrialCount
                    )
                )
            }
        }
        .overlay(alignment: .leading) {
            screenToggleEdgeSwipeHandle
        }
    }

    /// 左端からの右スワイプだけでメイン画面⇔トップ画面を切り替える。
    /// 表や行き先バーの上での誤発火を避けるため、ヒット領域を画面左端に限定する。
    private var screenToggleEdgeSwipeHandle: some View {
        Color.clear
            .frame(width: 24)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard horizontal > 60, abs(horizontal) > abs(vertical) * 1.5 else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsTopScreen.toggle()
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private var mainScreenContent: some View {
        GeometryReader { geometry in
            let isZoomedCompact = KeypadMetrics.isZoomedCompact(screenHeight: geometry.size.height)
            let locationCardHeight = ScreenChrome.locationRowHeight * 2 + 1
            let available = geometry.size.height
                - ScreenChrome.topPadding
                - ScreenChrome.bottomPadding
                - locationCardHeight
                - ScreenChrome.sectionSpacing * 2
            let minBanner: CGFloat = isZoomedCompact ? 88 : 110
            let desiredKeypad = geometry.size.height * 0.48
            let keypadHeight = max(200, min(desiredKeypad, available - minBanner))

            VStack(spacing: ScreenChrome.sectionSpacing) {
                OriginDestinationCard(
                    destinationLabel: destinationLabel,
                    hasDestination: viewModel.hasDestination,
                    isDestinationDisabled: viewModel.ridingState != nil,
                    currentLocationStatusText: currentLocationStatusText,
                    isUpdatingCurrentLocation: locationService.isUpdating,
                    showsLocationSettingsAction: locationService.isDenied,
                    hasManualOrigin: viewModel.hasManualOrigin,
                    onDestinationTap: { showsDestinationSheet = true },
                    onDestinationMapPick: {
                        mapPickerInitialRole = .destination
                        showsMapLocationPicker = true
                    },
                    onCurrentLocationRefresh: { handleCurrentLocationRefreshTap() },
                    onOpenLocationSettings: openAppSettings,
                    onClearManualOrigin: { viewModel.clearManualOrigin() },
                    onCurrentLocationMapPick: {
                        mapPickerInitialRole = .origin
                        showsMapLocationPicker = true
                    },
                    onCurrentLocationTap: { showsOriginSearchSheet = true }
                )

                verdictCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .frame(height: keypadHeight)
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, ScreenChrome.topPadding)
            .padding(.bottom, ScreenChrome.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .busMainScreenStyled()
            .environment(\.mainScreenCompactLayout, isZoomedCompact)
        }
    }

    var body: some View {
        NavigationStack {
            screenContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // トップ・メインどちらも、距離が出せるとき、または乗車中（目的地未設定で「—」表示のときも含む）は常時表示。タップは乗車中のみ。
                if viewModel.topScreenDistanceMeters != nil || viewModel.ridingState != nil {
                    let badge = TopDistanceBadge(
                        distanceMeters: viewModel.topScreenDistanceMeters,
                        onTap: viewModel.ridingState != nil
                            ? {
                                guard !showsCancelNavigationConfirm else { return }
                                openRidingRouteMap()
                            }
                            : nil,
                        onLongPress: viewModel.hasDestination
                            ? { showsCancelNavigationConfirm = true }
                            : nil
                    )
                    // iOS 26 のツールバーは既定でガラス風の白いカプセル背景を自動で敷くため、
                    // バッジ自身の色付き背景だけを見せたい場合はそれを消す。
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .topBarLeading) { badge }
                            .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarLeading) { badge }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
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
            .sheet(isPresented: $showsOriginSearchSheet) {
                DestinationInputView(
                    currentDestination: manualOriginAsDestination,
                    onSelect: { viewModel.setManualOrigin(latitude: $0.latitude, longitude: $0.longitude, name: $0.name) },
                    onClear: { viewModel.clearManualOrigin() },
                    role: .origin
                )
                .environment(\.locale, locale)
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $boardingRouteMapSheet) { sheet in
                BoardingRouteMapCover(
                    sheet: sheet,
                    origin: {
                        if let lat = viewModel.effectiveOriginLatitude,
                           let lon = viewModel.effectiveOriginLongitude {
                            return RouteCoordinate(latitude: lat, longitude: lon)
                        }
                        return sheet.origin
                    }(),
                    ridingBusNumber: viewModel.ridingState?.busNumber,
                    ridingAlightCoordinate: viewModel.ridingAlightCoordinate.map {
                        RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude)
                    },
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
                .id("\(sheet.id)-\(viewModel.ridingState?.busNumber ?? "")")
                .environment(\.locale, locale)
                .environment(SharedMapsTrialStore.shared)
            }
            .sheet(item: $topBusRouteMapSelection) { selection in
                if let originLatitude = viewModel.effectiveOriginLatitude,
                   let originLongitude = viewModel.effectiveOriginLongitude,
                   let destination = viewModel.destination {
                    TransitRouteMapView(
                        routeIndex: selection.id,
                        route: selection.route,
                        origin: RouteCoordinate(latitude: originLatitude, longitude: originLongitude),
                        destination: destination,
                        ridingBusNumber: viewModel.ridingState?.busNumber,
                        ridingAlightCoordinate: viewModel.ridingAlightCoordinate.map {
                            RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude)
                        },
                        allRoutes: viewModel.accumulatedTransitRoutes,
                        routeOptionCount: viewModel.accumulatedTransitRoutes.count,
                        onSwitchRoute: { newIndex in
                            viewModel.switchBoardingRoute(to: newIndex)
                        },
                        onSelectRidingBus: { routeIndex, busNumber in
                            handleRidingBusLongPress(busNumber: busNumber) {
                                viewModel.startRidingForBusSelection(routeIndex: routeIndex, busNumber: busNumber)
                            }
                        }
                    )
                    .id("\(selection.id)-\(viewModel.ridingState?.busNumber ?? "")")
                    .environment(\.locale, locale)
                    .environment(SharedMapsTrialStore.shared)
                }
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
            .sheet(item: $busRouteMapPresentation) { presentation in
                BusRouteMapCover(
                    presentation: presentation,
                    onStartRiding: { routeRef, candidate, detail in
                        // 路線図（メニュー経由）は乗車中でも開けるため、既に他の経路で乗車中なら
                        // ここからの乗車開始は無視し、既存の乗車状態を上書きしない。
                        guard viewModel.ridingState == nil else { return false }
                        viewModel.startRidingFromOSMMap(
                            routeRef: routeRef,
                            candidate: candidate,
                            routeDetail: detail
                        )
                        return true
                    },
                    onEndRiding: {
                        // 路線図の画面は維持したまま降車する（メイン画面へは戻らない）。
                        alightForTransfer()
                    }
                )
                .environment(\.locale, locale)
                .environment(SharedMapsTrialStore.shared)
            }
            .onAppear {
                locationService.refreshCurrentFromCache()
                locationService.fetchCurrentLocation()
                syncContinuousLocationTracking()
                applyPendingDeepLinkIfNeeded()
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: pendingDeepLinkDestination) { _, _ in
                applyPendingDeepLinkIfNeeded()
            }
            .onChange(of: locationFixToken) { _, _ in
                // 距離アラートは MainViewModel が測位のたびに実行する。
                // ここではシートを開いていないときの経路再検索だけ行う。
                guard busRouteMapPresentation == nil,
                      boardingRouteMapSheet == nil else { return }

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
            .onReceive(NotificationCenter.default.publisher(for: .osmBusOpenAPISettings)) { _ in
                topBusRouteMapSelection = nil
                boardingRouteMapSheet = nil
                busRouteMapPresentation = nil
                showsMapLocationPicker = false
                opensAPISettingsOnLaunch = true
                showsSettings = true
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
            .confirmationDialog(
                AppLocaleString.text("ナビ中止_確認", locale: locale),
                isPresented: $showsCancelNavigationConfirm,
                titleVisibility: .visible
            ) {
                Button(AppLocaleString.text("ナビを中止", locale: locale), role: .destructive) {
                    cancelNavigation()
                }
                Button(AppLocaleString.text("キャンセル", locale: locale), role: .cancel) {}
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
        let isRiding = viewModel.ridingState != nil
        let needsTracking = isRiding
            || viewModel.shouldTrackRiding
            || boardingRouteMapSheet != nil
            || busRouteMapPresentation != nil
            || topBusRouteMapSelection != nil
        if needsTracking {
            // 乗車中はポリラインの有無にかかわらず測位を止めない。
            // 止めると乗換地点に近づいても残り距離が固まり、到着アラートが鳴らない。
            // 地図を眺めているだけの間は前面のみで十分なので iOS の自動休止に任せる。
            // ただし一番近い到着アラートが鳴った後は、降車ボタンの押し忘れで
            // バックグラウンド測位が延々と続き端末が発熱するのを避けるため、
            // 常時ONを自動的に解除する(乗車状態自体は降車ボタンを押すまで継続)。
            let allowsBackground = isRiding && !viewModel.ridingNearestAlertReached
            locationService.startContinuousTracking(allowsBackground: allowsBackground)
        } else if !isRiding {
            locationService.stopContinuousTrackingAndDisableBackground()
        }
    }

    /// 緯度だけを見ると、東西に走るバスでは位置が動いても再検索も距離更新のきっかけも起きない。
    private var locationFixToken: String {
        guard let coordinate = locationService.currentLocation else { return "" }
        return "\(coordinate.latitude),\(coordinate.longitude)"
    }

    private var continuousLocationTrackingKey: String {
        [
            viewModel.ridingState == nil ? "0" : "1",
            viewModel.shouldTrackRiding ? "1" : "0",
            viewModel.ridingNearestAlertReached ? "1" : "0",
            boardingRouteMapSheet.map { String($0.id) } ?? "",
            busRouteMapPresentation?.id.uuidString ?? "",
            topBusRouteMapSelection.map { String($0.id) } ?? ""
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

    /// 判定バナー専用カード。行が増えてもこの枠内だけスクロールし、目的地・出発地は動かさない。
    private var verdictCard: some View {
        VStack(spacing: 0) {
            if showsAPIKeyPrompt {
                APIKeySetupBanner(isTrialExhausted: isTrialExhaustedWithoutUserKey) {
                    opensAPISettingsOnLaunch = true
                    showsSettings = true
                }
                Divider().padding(.leading, AppTheme.cardPaddingH + 10)
            }

            GeometryReader { bannerGeo in
                ScrollView(.vertical, showsIndicators: true) {
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
                            alightForTransfer()
                        } : nil,
                        fillsAvailableHeight: false
                    )
                    .environment(\.busCardStyle, .flat)
                    .frame(
                        minWidth: bannerGeo.size.width,
                        minHeight: bannerGeo.size.height,
                        alignment: .center
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .background(BusCardBackground(style: cardStyle))
    }

    private func applyPendingDeepLinkIfNeeded() {
        guard let destination = pendingDeepLinkDestination else { return }
        viewModel.setDestination(destination)
        pendingDeepLinkDestination = nil
        viewModel.refreshTransitRoutes(userInitiated: true)
        topBusRouteMapSelection = nil
        boardingRouteMapSheet = nil
        busRouteMapPresentation = nil
        showsTopScreen = true
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
                screenToggleTitleKey: showsTopScreen ? "メイン画面" : "トップ画面",
                onToggleScreen: {
                    performMoreAction {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsTopScreen.toggle()
                        }
                    }
                },
                onRouteMap: {
                    // メニューからの路線図は乗車中かどうかに関わらず、常に任意のバスを検索できる一覧を開く。
                    performMoreAction { openBrowseRouteMap() }
                },
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
        // 乗車中は経路データベース・乗車状態・目的地を消さない。確認ダイアログも出さない。
        if viewModel.ridingState != nil {
            viewModel.clearManualOriginWhileRiding()
            locationService.fetchCurrentLocation()
            return
        }
        guard viewModel.hasAccumulatedTransitRoutes else {
            locationService.fetchCurrentLocation()
            return
        }
        showsRouteDatabaseResetConfirm = true
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
            alightForTransfer()
        } else {
            selectRidingBus()
        }
    }

    /// 乗換のための降車直後処理: 長押し降車・メイン画面の「降車」ボタン共通 (Step 8)。
    /// 番号欄・蓄積経路・目的地は消さず、現在地を取り直して新しい出発地から経路を取り直す。
    /// 最終降車(ナビ終了)や目的地クリア(Step 9)とは別。
    private func alightForTransfer() {
        viewModel.endRiding()
        viewModel.clearManualOriginWhileRiding()
        locationService.fetchCurrentLocation()
        viewModel.refreshTransitRoutes(userInitiated: true)
    }

    /// 目的地バーの左スワイプ中止 (Step 9): 乗車中なら降車し、目的地・蓄積経路を消す。
    private func cancelNavigation() {
        if viewModel.ridingState != nil {
            viewModel.endRiding()
        }
        viewModel.clearDestination()
    }

    /// トップのバス番号表タップ: 表がその番号を載せたルート（乗車停が近い方）を開く。
    private func handleTopBusNumberTap(routeIndex: Int, busNumber _: String) {
        guard routeIndex >= 0, routeIndex < viewModel.accumulatedTransitRoutes.count else { return }
        let route = viewModel.accumulatedTransitRoutes[routeIndex]
        guard GoogleRoutesAPIService.routeHasMapGeometry(route) else { return }
        topBusRouteMapSelection = TransitRouteMapSelection(id: routeIndex, route: route)
    }

    /// トップのバス番号表長押し: 表と同じルートで乗車/降車トグル。
    private func handleTopBusNumberLongPress(routeIndex: Int, busNumber: String) {
        handleRidingBusLongPress(busNumber: busNumber) {
            viewModel.startRidingForBusSelection(routeIndex: routeIndex, busNumber: busNumber)
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
        boardingRouteMapSheet = BoardingRouteMapSheetModel(
            id: index,
            route: route,
            origin: RouteCoordinate(latitude: originLatitude, longitude: originLongitude),
            destination: destination,
            routeOptionCount: viewModel.accumulatedTransitRoutes.count
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
}

private struct BusRouteMapCover: View {
    let presentation: BusRouteMapPresentation
    let onStartRiding: (String, BusRouteCandidate, BusRouteDetail) -> Bool
    let onEndRiding: () -> Void

    var body: some View {
        BusRouteMapSheet(
            presentation: presentation,
            onStartRiding: onStartRiding,
            onEndRiding: onEndRiding
        )
    }
}

private struct BoardingRouteMapCover: View {
    let sheet: BoardingRouteMapSheetModel
    /// 乗降・出発地のたびに viewModel から直読みする(スナップショットだと距離が固まる)。
    let origin: RouteCoordinate
    let ridingBusNumber: String?
    let ridingAlightCoordinate: RouteCoordinate?
    let onSwitchRoute: (Int) -> Void
    let onLoadRouteOptions: () -> [ParsedTransitRoute]
    let onSelectRidingBus: (Int, String) -> Void

    var body: some View {
        TransitRouteMapView(
            routeIndex: sheet.id,
            route: sheet.route,
            origin: origin,
            destination: sheet.destination,
            ridingBusNumber: ridingBusNumber,
            ridingAlightCoordinate: ridingAlightCoordinate,
            routeOptionCount: sheet.routeOptionCount,
            onLoadRouteOptions: onLoadRouteOptions,
            onSwitchRoute: onSwitchRoute,
            onSelectRidingBus: onSelectRidingBus
        )
    }
}

private struct BusRouteMapSheet: View {
    let presentation: BusRouteMapPresentation
    let onStartRiding: (String, BusRouteCandidate, BusRouteDetail) -> Bool
    let onEndRiding: () -> Void

    var body: some View {
        switch presentation.mode {
        case .browse:
            BusRouteMapView(
                currentLatitude: presentation.latitude,
                currentLongitude: presentation.longitude,
                destination: presentation.destination,
                onStartRiding: onStartRiding,
                onEndRiding: onEndRiding
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
                onEndRiding: onEndRiding
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
}

#Preview {
    MainView(pendingDeepLinkDestination: .constant(nil))
        .environment(\.locale, Locale(identifier: "ja"))
        .environment(SharedRoutesTrialStore.shared)
}
