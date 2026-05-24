import SwiftUI

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppAppearanceStore.self) private var appearance
    @Environment(ColorThemeManager.self) private var themeManager
    @Environment(SharedRoutesTrialStore.self) private var trialStore
    @AppStorage(GoogleRoutesAPIKeyStore.userDefaultsKey) private var storedAPIKey = ""
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
        appearance.resolvedSceneColor(colorScheme: colorScheme)
    }

    private var effectiveColorScheme: ColorScheme {
        appearance.sceneColorScheme(for: colorScheme)
    }

    private var destinationLabel: String {
        viewModel.destination?.name ?? AppLocaleString.text("目的地を設定", locale: locale)
    }

    private var currentLocationStatusText: String {
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
                AppearanceBackgroundLayer(
                    texture: appearance.texture,
                    colorScheme: effectiveColorScheme,
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
                            onCharacter: { viewModel.appendBusCharacter($0) },
                            onDelete: { viewModel.deleteLastCharacter() },
                            onClear: { viewModel.clearBusNumber() }
                        )
                        .environment(\.mainScreenCompactLayout, isZoomedCompact)
                        .padding(.horizontal, AppTheme.screenPadding)
                        .padding(.bottom, isZoomedCompact ? 6 : 8)
                        .frame(height: halfHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .busMainScreenThemed()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar(themeManager.currentTheme)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("osmBus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(
                                themeManager.currentTheme.accentColor.readable(against: sceneColor)
                            )

                        if showsTrialRemainingLabel {
                            Text(
                                AppLocaleString.formatted(
                                    "osmBus_お試し残り_%d",
                                    locale: locale,
                                    trialStore.remainingTrialCount
                                )
                            )
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(
                                themeManager.currentTheme.accentColor.readable(against: sceneColor).opacity(0.88)
                            )
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    moreMenu
                }
            }
            .sheet(isPresented: $showsSettings) {
                AppSettingsView(opensAPISettingsOnAppear: opensAPISettingsOnLaunch)
                    .environment(\.locale, locale)
                    .environment(ColorThemeManager.shared)
                    .environment(AppAppearanceStore.shared)
                    .presentationDragIndicator(.visible)
                    .onDisappear {
                        opensAPISettingsOnLaunch = false
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
                    originLatitude: viewModel.currentLatitude,
                    originLongitude: viewModel.currentLongitude,
                    loadState: viewModel.transitRoutesLoadState,
                    routes: viewModel.transitRoutes,
                    onReload: { viewModel.refreshTransitRoutes(userInitiated: true) }
                )
                .environment(\.locale, locale)
            }
            .onAppear {
                locationService.refreshCurrentFromCache()
                viewModel.updateCurrentLocation(locationService.currentLocation)
                locationService.fetchCurrentLocation()
                applyPendingDeepLinkIfNeeded()
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: pendingDeepLinkDestination) { _, _ in
                applyPendingDeepLinkIfNeeded()
            }
            .onChange(of: locationService.currentLocation?.latitude) { _, _ in
                viewModel.updateCurrentLocation(locationService.currentLocation)
                viewModel.refreshBusCheck()
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                locationService.fetchCurrentLocation()
                viewModel.refreshBusCheck()
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: storedAPIKey) { _, _ in
                trialStore.refresh()
                viewModel.refreshBusCheck()
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: viewModel.destination?.id) { _, _ in
                viewModel.refreshTransitRoutes()
            }
            .onChange(of: viewModel.resultState) { _, newState in
                guard case .trialExhausted = newState else { return }
                showsTrialExhaustedAlert = true
            }
            .alert(
                AppLocaleString.text("osmBus_お試し枠_使い切り_タイトル", locale: locale),
                isPresented: $showsTrialExhaustedAlert
            ) {
                Button(AppLocaleString.text("osmBus_お試し枠_設定を開く", locale: locale)) {
                    opensAPISettingsOnLaunch = true
                    showsSettings = true
                }
                Button(AppLocaleString.text("OK", locale: locale), role: .cancel) {}
            } message: {
                Text(AppLocaleString.text("osmBus_お試し枠_使い切り_説明", locale: locale))
            }
        }
        .tint(themeManager.currentTheme.accentColor.readable(against: sceneColor))
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
                onTap: { showsDestinationSheet = true }
            )
            .frame(maxHeight: .infinity)

            if viewModel.hasDestination && canUseRoutesAPI {
                transitRoutesAccessButton
                    .frame(maxHeight: .infinity)
            }

            CurrentLocationBarView(
                statusText: currentLocationStatusText,
                isUpdating: locationService.isUpdating,
                showsSettingsAction: locationService.isDenied,
                onRefresh: { locationService.fetchCurrentLocation() },
                onOpenSettings: openAppSettings
            )
            .frame(maxHeight: .infinity)

            ResultBannerView(
                state: viewModel.resultState,
                busNumber: viewModel.enteredBusNumber,
                onRetry: viewModel.enteredBusNumber.isEmpty ? nil : {
                    viewModel.refreshBusCheck()
                }
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
                    Text(AppLocaleString.text("osmBus_経路を見る", locale: locale))
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
            .background(BusCardBackground(style: appearance.resolvedFrameStyle()))
        }
        .buttonStyle(.plain)
    }

    private var transitRoutesSubtitle: String {
        switch viewModel.transitRoutesLoadState {
        case .idle, .loading:
            return AppLocaleString.text("osmBus_経路読込中", locale: locale)
        case .loaded:
            return AppLocaleString.formatted(
                "osmBus_経路件数_%d",
                locale: locale,
                viewModel.transitRoutes.count
            )
        case .failed:
            return AppLocaleString.text("osmBus_経路取得失敗", locale: locale)
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
                .foregroundStyle(
                    themeManager.currentTheme.accentColor.readable(against: sceneColor)
                )
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
}

#Preview {
    MainView(pendingDeepLinkDestination: .constant(nil))
        .environment(\.locale, Locale(identifier: "ja"))
        .environment(ColorThemeManager.shared)
        .environment(AppAppearanceStore.shared)
        .environment(SharedRoutesTrialStore.shared)
}
