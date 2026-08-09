import Combine
import CoreLocation
import Foundation
import Observation
import UIKit

enum BusNumberInput {
    static let maxLength = 4

    static func normalizedCharacter(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let character = trimmed.first, character.isNumber else { return nil }
        return String(character)
    }

    static func canAppend(_ character: String, to current: String) -> Bool {
        guard current.count < maxLength else { return false }
        return normalizedCharacter(character) != nil
    }
}

@MainActor
@Observable
final class MainViewModel {
    private(set) var destination: Destination?
    private(set) var currentLatitude: Double?
    private(set) var currentLongitude: Double?
    private(set) var manualOriginLatitude: Double?
    private(set) var manualOriginLongitude: Double?
    private(set) var manualOriginName: String?
    var enteredBusNumber = ""
    var resultState: ResultDisplayState = .idle
    private(set) var otherBoardableVariants: [String] = []
    private let ridingTracker = RidingTracker()

    var ridingState: RidingState? { ridingTracker.ridingState }
    var shouldTrackRiding: Bool { ridingTracker.shouldTrackRiding }
    var isOSMMapRiding: Bool { ridingTracker.isOSMMapRiding }
    var osmRidingRouteCandidate: BusRouteCandidate? { ridingTracker.osmRidingRouteCandidate }
    var osmRidingRouteDetail: BusRouteDetail? { ridingTracker.osmRidingRouteDetail }
    var wrongDirectionDetected: Bool { ridingTracker.wrongDirectionDetected }
    var ridingNearestAlertReached: Bool { ridingTracker.nearestDistanceAlertReached }
    var activeRidingAlert: ActiveRidingAlert? { ridingTracker.activeAlert }
    var ridingAlightCoordinate: CLLocationCoordinate2D? { ridingTracker.alightCoordinate }

    var destinationLabel: String {
        destination?.name ?? AppLocaleString.currentText("目的地を設定")
    }

    var hasDestination: Bool {
        destination != nil
    }

    var hasManualOrigin: Bool { manualOriginLatitude != nil }

    var effectiveOriginLatitude: Double? { manualOriginLatitude ?? currentLatitude }
    var effectiveOriginLongitude: Double? { manualOriginLongitude ?? currentLongitude }

    var hasCurrentLocation: Bool {
        effectiveOriginLatitude != nil && effectiveOriginLongitude != nil
    }

    var currentLocationCoordinateText: String? {
        guard let lat = effectiveOriginLatitude, let lon = effectiveOriginLongitude else { return nil }
        return AppLocaleString.currentFormatted(
            "座標表示",
            String(format: "%.5f", lat),
            String(format: "%.5f", lon)
        )
    }

    enum ResultDisplayState: Equatable {
        case idle
        case checking
        case canBoard(arrivalText: String, alightStopText: String, directionHint: String?)
        case canBoardIfVariant(variantNames: [String], arrivalText: String, alightStopText: String, directionHint: String?)
        case cannotBoard
        case noTransitRoutes
        case trialExhausted
        case error(String)
    }

    enum TransitRoutesLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var transitRoutesLoadState: TransitRoutesLoadState = .idle
    /// 目的地を設定してから見つかった経路の蓄積データベース。GoogleのAPIは呼ぶたびに
    /// 微妙に結果が変わることがあり、直前の1回だけを見ているとさっきまであった候補が
    /// 消えて見えることがある。一度見つかった経路は上書き更新しつつ保持し続ける。
    private(set) var accumulatedTransitRoutes: [ParsedTransitRoute] = []
    private(set) var boardingRouteIndex: Int?
    private(set) var boardingRoute: ParsedTransitRoute?

    private(set) var isBoardingRouteCheapest: Bool = true

    private var busCheckTask: Task<Void, Never>?
    private var transitRoutesTask: Task<Void, Never>?
    private var lastAutoTransitRoutesRefreshTime: Date?
    private var lastAutoBusCheckRefreshTime: Date?
    /// 結果表示後クリアモードで、新しい番号を入力し始めたあとの1回の入力セッション。
    private var isComposingNewBusNumber = false
    private let resultHaptic = UINotificationFeedbackGenerator()
    /// ハプティクの重複判定用。resultState は判定中に .checking を挟むため、これとは別に最後に確定した結果を追跡する。
    private var lastSettledResultState: ResultDisplayState?

    init() {
        destination = DestinationStore.load()
    }

    func updateCurrentLocation(_ coordinate: CLLocationCoordinate2D?) {
        currentLatitude = coordinate?.latitude
        currentLongitude = coordinate?.longitude
    }

    func setDestination(_ destination: Destination) {
        self.destination = destination
        DestinationStore.save(destination)
        DestinationHistoryStore.add(destination)
        clearBusNumber()
        resetTransitRoutes()
    }

    func clearDestination() {
        destination = nil
        DestinationStore.save(nil)
        clearBusNumber()
        resetTransitRoutes()
    }

    func setManualOrigin(latitude: Double, longitude: Double, name: String) {
        manualOriginLatitude = latitude
        manualOriginLongitude = longitude
        manualOriginName = name
        resetTransitRoutes()
        refreshTransitRoutes()
        if !enteredBusNumber.isEmpty { refreshBusCheck() }
    }

    func clearManualOrigin() {
        manualOriginLatitude = nil
        manualOriginLongitude = nil
        manualOriginName = nil
        resetTransitRoutes()
        refreshTransitRoutes()
        if !enteredBusNumber.isEmpty { refreshBusCheck() }
    }

    func refreshTransitRoutes(userInitiated: Bool = false) {
        if !userInitiated {
            let now = Date()
            if let last = lastAutoTransitRoutesRefreshTime, now.timeIntervalSince(last) < 60 {
                return
            }
            lastAutoTransitRoutesRefreshTime = now
        }

        transitRoutesTask?.cancel()

        guard let destination, hasCurrentLocation,
              let originLatitude = effectiveOriginLatitude,
              let originLongitude = effectiveOriginLongitude else {
            clearTransitRoutesDisplay()
            return
        }

        let resolution = RoutesAPIKeyResolver.resolve(
            for: .transitRoutes(destinationID: destination.id),
            consumeTrial: userInitiated
        )
        guard let apiKey = resolution.apiKey else {
            switch resolution.unavailableReason {
            case .trialExhausted:
                transitRoutesLoadState = .failed(
                    AppLocaleString.currentText("お試し枠_使い切り")
                )
            default:
                // 自動更新はトライアルを消費しない設計のため、まだ一度も手動で
                // 経路一覧を開いていないとここに来ることがある。よくある一時的な
                // 状態なので、表示だけ空にして蓄積データベースは保持する。
                clearTransitRoutesDisplay()
            }
            return
        }

        transitRoutesLoadState = .loading

        transitRoutesTask = Task {
            let result = await GoogleRoutesAPIService.fetchTransitRoutes(
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                destinationLatitude: destination.latitude,
                destinationLongitude: destination.longitude,
                apiKey: apiKey
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                switch result {
                case .success(let routes):
                    mergeIntoAccumulatedRoutes(routes)
                    // 今回の取得が空でも、蓄積データベースに何かあればそれを表示できる状態とみなす。
                    transitRoutesLoadState = accumulatedTransitRoutes.isEmpty
                        ? .failed(AppLocaleString.currentText("ルートなし"))
                        : .loaded
                case .failure(let error):
                    transitRoutesLoadState = accumulatedTransitRoutes.isEmpty
                        ? .failed(AppLocaleString.userFacingError(error))
                        : .loaded
                }
            }
        }
    }

    /// 新しい旅の開始(目的地・出発地の変更)以外では呼ばないこと。
    /// 経路データベース(蓄積分)ごと消去する。
    private func resetTransitRoutes() {
        accumulatedTransitRoutes = []
        clearTransitRoutesDisplay()
    }

    var hasAccumulatedTransitRoutes: Bool {
        !accumulatedTransitRoutes.isEmpty
    }

    /// 現在地更新時にユーザーが明示的に選んだ場合に呼ぶ。経路データベースを消去する。
    func resetAccumulatedTransitRoutes() {
        resetTransitRoutes()
    }

    /// 経路一覧の表示状態だけを消去する。蓄積データベースには触れない。
    /// APIキー未解決など「今回だけ更新できなかった」場合に使う—ここで蓄積分まで
    /// 消してしまうと、位置情報の自動更新のたびにせっかくのデータベースが
    /// クリアされてしまう。
    private func clearTransitRoutesDisplay() {
        transitRoutesTask?.cancel()
        transitRoutesLoadState = accumulatedTransitRoutes.isEmpty ? .idle : .loaded
        lastAutoTransitRoutesRefreshTime = nil
    }

    /// 新しく見つかった経路をデータベースに蓄積する。バスの並び(系統の組み合わせ)が
    /// 同じ経路は同一route とみなし、新しい方(所要時間・運賃が最新)で上書きする。
    private func mergeIntoAccumulatedRoutes(_ newRoutes: [ParsedTransitRoute]) {
        for route in newRoutes {
            let key = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: route).joined(separator: "→")
            if !key.isEmpty {
                accumulatedTransitRoutes.removeAll {
                    GoogleRoutesAPIService.transitBusLineBadgeLabels(for: $0).joined(separator: "→") == key
                }
            }
            accumulatedTransitRoutes.append(route)
        }
    }

    func appendBusCharacter(_ raw: String) {
        guard let character = BusNumberInput.normalizedCharacter(raw) else { return }

        if BusKeypadInputMode.current == .clearBeforeNewInput, hasSettledBusCheckResult {
            if !isComposingNewBusNumber {
                busCheckTask?.cancel()
                enteredBusNumber = ""
                resultState = .idle
                isComposingNewBusNumber = true
            } else {
                busCheckTask?.cancel()
                resultState = .idle
            }
        }

        guard BusNumberInput.canAppend(character, to: enteredBusNumber) else { return }
        enteredBusNumber += character
        scheduleBusCheck()
    }

    private var hasSettledBusCheckResult: Bool {
        switch resultState {
        case .canBoard, .canBoardIfVariant, .cannotBoard, .noTransitRoutes, .error, .trialExhausted:
            return true
        case .idle, .checking:
            return false
        }
    }

    func deleteLastCharacter() {
        guard !enteredBusNumber.isEmpty else { return }
        enteredBusNumber.removeLast()
        scheduleBusCheck()
    }

    func clearBusNumber() {
        busCheckTask?.cancel()
        enteredBusNumber = ""
        resultState = .idle
        isComposingNewBusNumber = false
        boardingRouteIndex = nil
        boardingRoute = nil
        clearRidingState()
    }

    func submitBusCheck() {
        guard !enteredBusNumber.isEmpty else { return }
        scheduleBusCheck(immediate: true)
    }

    func refreshBusCheck(userInitiated: Bool = true) {
        if !userInitiated {
            let now = Date()
            if let last = lastAutoBusCheckRefreshTime, now.timeIntervalSince(last) < 20 {
                return
            }
            lastAutoBusCheckRefreshTime = now
        }
        submitBusCheck()
    }

    private func scheduleBusCheck(immediate: Bool = false) {
        busCheckTask?.cancel()

        guard !enteredBusNumber.isEmpty else {
            resultState = .idle
            return
        }

        busCheckTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: busCheckDebounceNanoseconds(for: enteredBusNumber.count))
            }
            guard !Task.isCancelled else { return }
            await performBusCheck()
        }
    }

    /// 入力途中の部分判定を減らすため、桁数が少ないほど待ち時間を長くする。
    private func busCheckDebounceNanoseconds(for length: Int) -> UInt64 {
        switch length {
        case 1:
            return 2_500_000_000
        case 2:
            return 1_500_000_000
        default:
            return 900_000_000
        }
    }

    @MainActor
    private func performBusCheck() async {
        resultState = .checking

        guard let destination else {
            applyResultState(.error(AppLocaleString.currentText("エラー_目的地未設定")))
            return
        }

        guard let originLatitude = effectiveOriginLatitude,
              let originLongitude = effectiveOriginLongitude else {
            applyResultState(.error(AppLocaleString.currentText("エラー_現在地未取得")))
            return
        }

        let busNumber = enteredBusNumber
        let resolution = RoutesAPIKeyResolver.resolve(
            for: .busCheck(busNumber: busNumber, destinationID: destination.id)
        )
        guard let apiKey = resolution.apiKey else {
            switch resolution.unavailableReason {
            case .trialExhausted:
                applyResultState(.trialExhausted)
            default:
                applyResultState(.error(AppLocaleString.currentText("エラー_APIキー未設定")))
            }
            return
        }

        let distanceMeters = GoogleRoutesAPIService.distanceMeters(
            fromLatitude: originLatitude,
            fromLongitude: originLongitude,
            toLatitude: destination.latitude,
            toLongitude: destination.longitude
        )
        if distanceMeters > 80_000 {
            applyResultState(.error(
                AppLocaleString.currentFormatted("エラー_距離超過_%d", Int(distanceMeters / 1000))
            ))
            return
        }

        // 経路データベースを最新化してから、蓄積された経路全体に対して番号を判定する。
        // 直近1回のAPI応答だけを見ないことで、少し前まであった候補が今回だけたまたま
        // 返ってこなかったせいで誤って「見送ってください」と判定するのを防ぐ。
        let result = await GoogleRoutesAPIService.fetchTransitRoutes(
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destinationLatitude: destination.latitude,
            destinationLongitude: destination.longitude,
            apiKey: apiKey
        )

        guard !Task.isCancelled, enteredBusNumber == busNumber else { return }

        switch result {
        case .failure(let error):
            applyResultState(.error(AppLocaleString.userFacingError(error)))
            return
        case .success(let routes):
            mergeIntoAccumulatedRoutes(routes)
        }

        guard !accumulatedTransitRoutes.isEmpty else {
            applyResultState(.noTransitRoutes)
            return
        }

        let response = GoogleRoutesAPIService.evaluateBusQuery(busNumber, routes: accumulatedTransitRoutes)

        switch response.outcome {
        case .boardAll(let arrivalText, let alightStopText):
            applyResultState(
                .canBoard(arrivalText: arrivalText, alightStopText: alightStopText, directionHint: response.boardingDirectionHint),
                boardingRouteIndex: response.matchingRouteIndex,
                boardingRoute: response.matchingRoute,
                isBoardingRouteCheapest: response.isBoardingRouteCheapest
            )
        case .boardIfVariant(let names, let arrivalText, let alightStopText):
            applyResultState(
                .canBoardIfVariant(
                    variantNames: names,
                    arrivalText: arrivalText,
                    alightStopText: alightStopText,
                    directionHint: response.boardingDirectionHint
                ),
                boardingRouteIndex: response.matchingRouteIndex,
                boardingRoute: response.matchingRoute,
                isBoardingRouteCheapest: response.isBoardingRouteCheapest
            )
            checkOtherVariantsInOSM(busNumber: busNumber, knownVariants: names)
        case .doNotBoard:
            applyResultState(.cannotBoard)
        case .noTransitRoutes:
            applyResultState(.noTransitRoutes)
        case .configurationError(let message), .apiError(let message):
            applyResultState(.error(message))
        }
    }

    private func applyResultState(
        _ state: ResultDisplayState,
        boardingRouteIndex: Int? = nil,
        boardingRoute: ParsedTransitRoute? = nil,
        isBoardingRouteCheapest: Bool = true
    ) {
        let previous = lastSettledResultState
        resultState = state
        if case .canBoardIfVariant = state {} else {
            otherBoardableVariants = []
        }
        switch state {
        case .canBoard, .canBoardIfVariant:
            self.boardingRouteIndex = boardingRouteIndex
            self.boardingRoute = boardingRoute
            self.isBoardingRouteCheapest = isBoardingRouteCheapest
        default:
            // 乗車中は boardingRoute と ridingState を保持する
            if ridingTracker.ridingState == nil {
                self.boardingRouteIndex = nil
                self.boardingRoute = nil
                self.isBoardingRouteCheapest = true
                clearRidingState()
            }
        }
        // 同じ結果の繰り返し更新ではハプティクを鳴らさない
        if state != previous {
            playResultHaptic(for: state)
        }
        lastSettledResultState = state
        registerCompletedBusCheck()
    }

    private func checkOtherVariantsInOSM(busNumber: String, knownVariants: [String]) {
        otherBoardableVariants = []
        guard let lat = effectiveOriginLatitude,
              let lon = effectiveOriginLongitude else { return }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let knownSet = Set(knownVariants)
        Task { @MainActor in
            guard let candidates = try? await OverpassAPIService.searchCandidates(
                ref: busNumber, near: coord, radiusMeters: 30_000
            ) else { return }
            let others = candidates.map { $0.ref }.filter { !knownSet.contains($0) }
            guard !others.isEmpty else { return }
            guard case .canBoardIfVariant = resultState, enteredBusNumber == busNumber else { return }
            otherBoardableVariants = others
        }
    }

    func prepareBoardingRouteForVariant(_ variantName: String) {
        if let match = GoogleRoutesAPIService.findMatchingRouteWithIndex(routes: accumulatedTransitRoutes, busNumber: variantName) {
            boardingRouteIndex = match.index
            boardingRoute = match.route
        }
    }

    func resolvedBoardingBusRef(overrideVariant: String? = nil) -> String {
        if let overrideVariant, !overrideVariant.isEmpty {
            return overrideVariant
        }
        if case .canBoardIfVariant(let names, _, _, _) = resultState,
           names.count == 1,
           let only = names.first {
            return only
        }
        if let route = boardingRoute,
           let ref = GoogleRoutesAPIService.primaryBusLineRef(route: route, busNumber: enteredBusNumber),
           !ref.isEmpty {
            return ref
        }
        return enteredBusNumber
    }

    func startRidingFromOSMMap(routeRef: String, candidate: BusRouteCandidate, routeDetail: BusRouteDetail? = nil) {
        ridingTracker.startFromOSMMap(
            routeRef: routeRef,
            candidate: candidate,
            routeDetail: routeDetail,
            destination: destination
        )
        ridingTracker.enableLocationTrackingIfNeeded()
        syncEnteredBusNumber()
    }

    func switchBoardingRoute(to index: Int) {
        guard index >= 0, index < accumulatedTransitRoutes.count else { return }
        boardingRouteIndex = index
        boardingRoute = accumulatedTransitRoutes[index]
        guard ridingTracker.isActive else { return }
        ridingTracker.updateRouteWhileRiding(
            route: boardingRoute,
            busNumber: enteredBusNumber,
            destination: destination
        )
    }

    func startRidingOnboarding(busNumber: String) {
        prepareBoardingRouteForVariant(busNumber)
        ridingTracker.buildRidingState(
            route: boardingRoute,
            busNumber: busNumber,
            destination: destination,
            startTracking: false
        )
        ridingTracker.enableLocationTrackingIfNeeded()
        syncEnteredBusNumber()
    }

    /// 経路候補・候補ルート画面でバス番号を長押しした際、現在の乗車状態を解除してそのバスに切り替える。
    func startRidingForBusSelection(routeIndex: Int, busNumber: String) {
        guard routeIndex >= 0, routeIndex < accumulatedTransitRoutes.count else { return }
        let route = accumulatedTransitRoutes[routeIndex]
        boardingRouteIndex = routeIndex
        boardingRoute = route
        // 乗車中の切り替えは、その路線の本来の乗車停留所ではなく現在地を乗車地点として使う。
        // 手前の停留所で既に乗り換え済みのケースで、逆方向誤検知や誤った距離アラームを防ぐため。
        let boardingLocationOverride: RouteCoordinate? = {
            guard let lat = currentLatitude, let lon = currentLongitude else { return nil }
            return RouteCoordinate(latitude: lat, longitude: lon)
        }()
        ridingTracker.buildRidingState(
            route: route,
            busNumber: busNumber,
            destination: destination,
            startTracking: false,
            boardingLocationOverride: boardingLocationOverride
        )
        ridingTracker.enableLocationTrackingIfNeeded()
        syncEnteredBusNumber()
    }

    func ridingBusCandidates(for input: String) -> [String] {
        GoogleRoutesAPIService.busLineCandidates(for: input, in: accumulatedTransitRoutes)
    }

    /// 乗車中にキーパッドへ別のバス番号を入力して乗り換えを選択した場合の処理。
    /// 単なる表示ラベルの変更ではなく、乗り換え先バスの区間として降車地点・ポリライン・
    /// 距離アラート状態を再構築する(そうしないと降車済みの停留所を基準に距離が
    /// 計算され続け、乗り換え後に距離がどんどん広がって見える不具合になる)。
    func overrideRidingBusNumber(_ busNumber: String) {
        guard let match = GoogleRoutesAPIService.findMatchingRouteWithIndex(
            routes: accumulatedTransitRoutes,
            busNumber: busNumber
        ) else {
            ridingTracker.overrideBusNumber(busNumber)
            syncEnteredBusNumber()
            return
        }
        boardingRouteIndex = match.index
        boardingRoute = match.route
        // 乗り換え時点の乗車停留所は、その区間の本来の乗車停留所ではなく現在地を使う
        // (手前の停留所で既に乗り換え済みのケースがあるため)。startRidingForBusSelection と同様。
        let boardingLocationOverride: RouteCoordinate? = {
            guard let lat = currentLatitude, let lon = currentLongitude else { return nil }
            return RouteCoordinate(latitude: lat, longitude: lon)
        }()
        ridingTracker.buildRidingState(
            route: match.route,
            busNumber: busNumber,
            destination: destination,
            startTracking: ridingTracker.shouldTrackRiding,
            boardingLocationOverride: boardingLocationOverride
        )
        ridingTracker.enableLocationTrackingIfNeeded()
        syncEnteredBusNumber()
    }

    /// enteredBusNumber は「乗車中バス」の表示にも使われるため、RidingTracker に実際に
    /// 反映された値で必ず上書きする(呼び出し元が渡した値をそのまま信用すると、
    /// buildRidingState 内のガード節で乗車開始に失敗した場合に表示だけがズレる)。
    private func syncEnteredBusNumber() {
        guard let actual = ridingTracker.ridingState?.busNumber else { return }
        enteredBusNumber = actual
    }

    func dismissWrongDirection() {
        ridingTracker.dismissWrongDirection()
    }

    func dismissActiveRidingAlert() {
        ridingTracker.dismissActiveAlert()
    }

    func checkRidingProgress(at coordinate: CLLocationCoordinate2D) {
        ridingTracker.checkProgress(at: coordinate, destination: destination)
    }

    private func clearRidingState() {
        ridingTracker.clear()
    }

    private func registerCompletedBusCheck() {
        guard hasSettledBusCheckResult else { return }
        isComposingNewBusNumber = false
    }

    private func playResultHaptic(for state: ResultDisplayState) {
        switch state {
        case .canBoard, .canBoardIfVariant:
            resultHaptic.notificationOccurred(.success)
        case .cannotBoard:
            resultHaptic.notificationOccurred(.warning)
        case .error:
            resultHaptic.notificationOccurred(.error)
        case .trialExhausted:
            resultHaptic.notificationOccurred(.warning)
        case .idle, .checking, .noTransitRoutes:
            break
        }
    }
}
