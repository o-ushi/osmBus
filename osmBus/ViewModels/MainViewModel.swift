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
    private let locationService: LocationService
    private(set) var destination: Destination?
    /// 現在地は `LocationService.currentLocation` を都度直接読む(コピーを持たない)。
    /// 以前はここへ View 層からプッシュしていたが、地図シート表示中は更新が止まる導線に
    /// なっていて、シートを開いたまま降車して乗り換え検索を続けるとホーム画面の距離表示が
    /// 固まったまま動かなくなる不具合の原因になっていた。
    var currentLatitude: Double? { locationService.currentLocation?.latitude }
    var currentLongitude: Double? { locationService.currentLocation?.longitude }
    /// 乗車中の残り距離用。手動出発地ではなく、届いた GPS そのもの。
    /// `@Observable` が追えるよう LocationService のコピーをここに持つ。
    private(set) var gpsLatitude: Double?
    private(set) var gpsLongitude: Double?
    @ObservationIgnored private var locationCancellable: AnyCancellable?
    private(set) var manualOriginLatitude: Double?
    private(set) var manualOriginLongitude: Double?
    private(set) var manualOriginName: String?
    var enteredBusNumber = ""
    var resultState: ResultDisplayState = .idle
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

    var hasDestination: Bool {
        destination != nil
    }

    var hasManualOrigin: Bool { manualOriginLatitude != nil }

    var effectiveOriginLatitude: Double? { manualOriginLatitude ?? currentLatitude }
    var effectiveOriginLongitude: Double? { manualOriginLongitude ?? currentLongitude }

    var hasCurrentLocation: Bool {
        effectiveOriginLatitude != nil && effectiveOriginLongitude != nil
    }

    /// 乗車中に降車座標が瞬間的に欠けても、距離バッジを消さないための直前値。
    private var lastRidingDistanceMeters: Double?

    /// トップ画面の距離欄用。
    /// - 目的地あり・未乗車: 現在地 → 目的地
    /// - 目的地あり・乗車中: ライブ GPS → 今のバス区間の降車停（乗換地点。手動出発地では測らない）
    /// - 目的地なし（乗車中含む）: nil。OSM 路線図から目的地未設定のまま乗車した場合、
    ///   `RidingTracker.resolveOSMAlightCoordinate` は路線の終点を降車座標として使うが、
    ///   それはユーザーの行き先ではなくナビとして意味が薄いため「あと」には出さない。
    /// 現在地または基準地点が無ければ nil。
    var topScreenDistanceMeters: Double? {
        if ridingState != nil, destination == nil {
            lastRidingDistanceMeters = nil
            return nil
        }
        if ridingState != nil {
            // 手動出発地のままだと、バスが動いても「あと」が乗った時点の距離で固まる。
            // 乗換後に降車地点だけ差し替わると、そこで初めて別の数字へ跳ぶ。
            let originLat = gpsLatitude ?? currentLatitude
            let originLon = gpsLongitude ?? currentLongitude
            guard let originLat, let originLon else { return lastRidingDistanceMeters }
            guard let alight = ridingAlightCoordinate else { return lastRidingDistanceMeters }
            let meters = GoogleRoutesAPIService.distanceMeters(
                fromLatitude: originLat,
                fromLongitude: originLon,
                toLatitude: alight.latitude,
                toLongitude: alight.longitude
            )
            lastRidingDistanceMeters = meters
            return meters
        }
        guard let originLat = effectiveOriginLatitude, let originLon = effectiveOriginLongitude else {
            lastRidingDistanceMeters = nil
            return nil
        }
        lastRidingDistanceMeters = nil
        guard let destination else { return nil }
        return GoogleRoutesAPIService.distanceMeters(
            fromLatitude: originLat,
            fromLongitude: originLon,
            toLatitude: destination.latitude,
            toLongitude: destination.longitude
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
    /// テンキー判定で「行き先案に無いが乗換地点まで行ける」と分かった系統。番号表には出さない。
    private var alternateBoardingRoutes: [String: ParsedTransitRoute] = [:]
    /// 同じ番号の再入力用。経路データベースの中身が変わったら無効化する。
    private var busCheckCache: [String: BusCheckSnapshot] = [:]
    private var busCheckCacheFingerprint = ""
    /// 代替乗車の重い検索(乗換地点への再検索 / OSM)を番号ごとに一度だけにする。
    private var alternateSearchCompletedFor: Set<String> = []
    /// 目的地ごとの経路。ユーザー初期化までディスクに残す。
    private var routeArchive: [String: TripRouteRecord] = [:]

    private var busCheckTask: Task<Void, Never>?
    private var transitRoutesTask: Task<Void, Never>?
    private var lastAutoTransitRoutesRefreshTime: Date?
    private var lastAutoBusCheckRefreshTime: Date?
    /// 結果表示後クリアモードで、新しい番号を入力し始めたあとの1回の入力セッション。
    private var isComposingNewBusNumber = false
    private let resultHaptic = UINotificationFeedbackGenerator()
    /// ハプティクの重複判定用。resultState は判定中に .checking を挟むため、これとは別に最後に確定した結果を追跡する。
    private var lastSettledResultState: ResultDisplayState?

    init(locationService: LocationService) {
        self.locationService = locationService
        destination = DestinationStore.load()
        routeArchive = TransitRouteArchive.load()
        activateBucketForCurrentDestination()
        // 画面の onChange(緯度だけ) ではなく、測位のたびに距離とアラートを進める。
        // 地図シート表示中や東西方向の移動でも、乗換地点までの距離が止まらないようにする。
        locationCancellable = locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                Task { @MainActor [weak self] in
                    self?.handleLocationFix(coordinate)
                }
            }
    }

    private func handleLocationFix(_ coordinate: CLLocationCoordinate2D) {
        gpsLatitude = coordinate.latitude
        gpsLongitude = coordinate.longitude
        if let busNumber = ridingState?.busNumber {
            ridingTracker.realignAlightWithRoute(
                boardingRoute,
                busNumber: busNumber,
                destination: destination
            )
        }
        locationService.updateAccuracy(distanceToTargetMeters: distanceFromFixToTarget(coordinate))
        ridingTracker.checkProgress(at: coordinate, destination: destination)
    }

    private func distanceFromFixToTarget(_ coordinate: CLLocationCoordinate2D) -> Double? {
        let target: CLLocationCoordinate2D?
        if let alight = ridingAlightCoordinate {
            target = alight
        } else if let destination {
            target = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        } else {
            target = nil
        }
        guard let target else { return nil }
        return GoogleRoutesAPIService.distanceMeters(
            fromLatitude: coordinate.latitude,
            fromLongitude: coordinate.longitude,
            toLatitude: target.latitude,
            toLongitude: target.longitude
        )
    }

    func setDestination(_ destination: Destination) {
        persistCurrentBucket()
        self.destination = destination
        DestinationStore.save(destination)
        DestinationHistoryStore.add(destination)
        clearBusNumber()
        activateBucketForCurrentDestination()
        refreshTransitRoutes(userInitiated: true)
    }

    func clearDestination() {
        persistCurrentBucket()
        destination = nil
        DestinationStore.save(nil)
        clearBusNumber()
        activateBucketForCurrentDestination()
    }

    func setManualOrigin(latitude: Double, longitude: Double, name: String) {
        persistCurrentBucket()
        manualOriginLatitude = latitude
        manualOriginLongitude = longitude
        manualOriginName = name
        refreshTransitRoutes(userInitiated: true)
        if !enteredBusNumber.isEmpty { refreshBusCheck() }
    }

    func clearManualOrigin() {
        persistCurrentBucket()
        manualOriginLatitude = nil
        manualOriginLongitude = nil
        manualOriginName = nil
        refreshTransitRoutes(userInitiated: true)
        if !enteredBusNumber.isEmpty { refreshBusCheck() }
    }

    /// 乗車中の現在地更新 (↻) 用。手動出発地は外して GPS に戻すが、経路データベース・
    /// 乗車状態・目的地は消さない (Step 6: 乗車中でも出発地を現在地に更新できる)。
    func clearManualOriginWhileRiding() {
        manualOriginLatitude = nil
        manualOriginLongitude = nil
        manualOriginName = nil
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
                transitRoutesLoadState = .failed(
                    AppLocaleString.currentText("エラー_APIキー未設定")
                )
            }
            return
        }

        transitRoutesLoadState = .loading

        transitRoutesTask = Task { @MainActor in
            let result = await GoogleRoutesAPIService.fetchTransitRoutes(
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                destinationLatitude: destination.latitude,
                destinationLongitude: destination.longitude,
                apiKey: apiKey
            )

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let routes):
                mergeIntoAccumulatedRoutes(routes)
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

    /// ユーザーが明示的に初期化したときだけ、保存済み経路をすべて捨てる。
    private func resetTransitRoutes() {
        routeArchive = [:]
        TransitRouteArchive.clear()
        accumulatedTransitRoutes = []
        busCheckCache = [:]
        busCheckCacheFingerprint = ""
        alternateSearchCompletedFor = []
        alternateBoardingRoutes = [:]
        clearTransitRoutesDisplay()
    }

    private var currentArchiveKey: String? {
        destination?.id
    }

    private func persistCurrentBucket() {
        guard let key = currentArchiveKey else { return }
        routeArchive[key] = TripRouteRecord(
            routes: accumulatedTransitRoutes,
            alternateRoutes: alternateBoardingRoutes,
            alternateSearchDone: Array(alternateSearchCompletedFor),
            updatedAt: Date(),
            destination: destination
        )
        TransitRouteArchive.save(routeArchive)
    }

    private func activateBucketForCurrentDestination() {
        busCheckCache = [:]
        busCheckCacheFingerprint = ""
        if let key = currentArchiveKey, let record = routeArchive[key] {
            accumulatedTransitRoutes = record.routes
            alternateBoardingRoutes = record.alternateRoutes
            alternateSearchCompletedFor = Set(record.alternateSearchDone)
            transitRoutesLoadState = accumulatedTransitRoutes.isEmpty ? .idle : .loaded
        } else {
            accumulatedTransitRoutes = []
            alternateBoardingRoutes = [:]
            alternateSearchCompletedFor = []
            transitRoutesLoadState = .idle
        }
        busCheckCacheFingerprint = accumulatedRoutesFingerprint
        lastAutoTransitRoutesRefreshTime = nil
    }

    var hasAccumulatedTransitRoutes: Bool {
        !accumulatedTransitRoutes.isEmpty
    }

    /// 現在地更新時にユーザーが明示的に初期化した場合。保存済み経路をすべて捨てる。
    func resetAccumulatedTransitRoutes() {
        resetTransitRoutes()
    }

    /// 経路一覧の表示状態だけを消去する。蓄積データベースには触れない。
    /// APIキー未解決など「今回だけ更新できなかった」場合に使う—ここで蓄積分まで
    /// 消してしまうと、位置情報の自動更新のたびにせっかくのデータベースが
    /// クリアされてしまう。
    private func clearTransitRoutesDisplay() {
        transitRoutesTask?.cancel()
        transitRoutesTask = nil
        transitRoutesLoadState = accumulatedTransitRoutes.isEmpty ? .idle : .loaded
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
        let fingerprint = accumulatedRoutesFingerprint
        if fingerprint != busCheckCacheFingerprint {
            busCheckCache = [:]
            busCheckCacheFingerprint = fingerprint
        }
        persistCurrentBucket()
    }

    private var accumulatedRoutesFingerprint: String {
        accumulatedTransitRoutes
            .map { GoogleRoutesAPIService.transitBusLineBadgeLabels(for: $0).joined(separator: "→") }
            .joined(separator: "|")
    }

    private struct BusCheckSnapshot {
        let resultState: ResultDisplayState
        let boardingRouteIndex: Int?
        let boardingRoute: ParsedTransitRoute?
        let isBoardingRouteCheapest: Bool
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

    func clearBusNumber() {
        busCheckTask?.cancel()
        enteredBusNumber = ""
        resultState = .idle
        isComposingNewBusNumber = false
        boardingRouteIndex = nil
        boardingRoute = nil
        alternateBoardingRoutes = [:]
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
            let canUseCache = busCheckCache[enteredBusNumber] != nil
                && busCheckCacheFingerprint == accumulatedRoutesFingerprint
            if !immediate, !canUseCache {
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

        // 同じ番号を打ち直したとき、保存済みの判定を先に出す。ルート再検索は待たない。
        if applyCachedBusCheck(for: busNumber) {
            await refreshDestinationRoutesInBackgroundIfStale(
                busNumber: busNumber,
                destination: destination,
                originLatitude: originLatitude,
                originLongitude: originLongitude
            )
            return
        }

        // トップ画面などで既に経路データベースがあるなら、それで即判定する。
        if !accumulatedTransitRoutes.isEmpty {
            await evaluateAgainstAccumulatedRoutes(
                busNumber: busNumber,
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                destination: destination,
                allowNetworkAlternate: true,
                showCheckingWhileWaiting: true
            )
            await refreshDestinationRoutesInBackgroundIfStale(
                busNumber: busNumber,
                destination: destination,
                originLatitude: originLatitude,
                originLongitude: originLongitude
            )
            return
        }

        resultState = .checking
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

        await evaluateAgainstAccumulatedRoutes(
            busNumber: busNumber,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destination: destination,
            allowNetworkAlternate: true,
            showCheckingWhileWaiting: true
        )
    }

    private func applyCachedBusCheck(for busNumber: String) -> Bool {
        guard busCheckCacheFingerprint == accumulatedRoutesFingerprint,
              let snapshot = busCheckCache[busNumber] else { return false }
        applyResultState(
            snapshot.resultState,
            boardingRouteIndex: snapshot.boardingRouteIndex,
            boardingRoute: snapshot.boardingRoute,
            isBoardingRouteCheapest: snapshot.isBoardingRouteCheapest
        )
        return true
    }

    private func evaluateAgainstAccumulatedRoutes(
        busNumber: String,
        originLatitude: Double,
        originLongitude: Double,
        destination: Destination,
        allowNetworkAlternate: Bool,
        showCheckingWhileWaiting: Bool
    ) async {
        guard !accumulatedTransitRoutes.isEmpty else {
            applyResultState(.noTransitRoutes)
            return
        }

        var response = GoogleRoutesAPIService.evaluateBusQuery(busNumber, routes: accumulatedTransitRoutes)
        if case .doNotBoard = response.outcome, allowNetworkAlternate {
            if let fromStoredMaps = GoogleRoutesAPIService.matchViaStoredLineMaps(
                busNumber: busNumber,
                destinationRoutes: accumulatedTransitRoutes,
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                destinationLatitude: destination.latitude,
                destinationLongitude: destination.longitude,
                destinationName: destination.name
            ) {
                response = fromStoredMaps
                rememberAlternateBoardingRoutes(from: fromStoredMaps)
            } else if let remembered = rememberedAlternateResponse(busNumber: busNumber) {
                response = remembered
            } else if !alternateSearchCompletedFor.contains(busNumber) {
                if showCheckingWhileWaiting, resultState != .checking {
                    resultState = .checking
                }
                let resolution = RoutesAPIKeyResolver.resolve(
                    for: .busCheck(busNumber: busNumber, destinationID: destination.id)
                )
                if let apiKey = resolution.apiKey {
                    if let alternate = await GoogleRoutesAPIService.evaluateAlternateTransferBoarding(
                        busNumber: busNumber,
                        destinationRoutes: accumulatedTransitRoutes,
                        originLatitude: originLatitude,
                        originLongitude: originLongitude,
                        destinationLatitude: destination.latitude,
                        destinationLongitude: destination.longitude,
                        destinationName: destination.name,
                        apiKey: apiKey
                    ) {
                        response = alternate
                        rememberAlternateBoardingRoutes(from: alternate)
                    }
                }
                alternateSearchCompletedFor.insert(busNumber)
                guard !Task.isCancelled, enteredBusNumber == busNumber else { return }
            }
        }

        applyBusCheckResponse(response, busNumber: busNumber)
    }

    private func rememberedAlternateResponse(busNumber: String) -> BusCheckResponse? {
        guard let route = alternateBoardingRoutes[busNumber]
            ?? alternateBoardingRoutes.first(where: { $0.key.caseInsensitiveCompare(busNumber) == .orderedSame })?.value
        else { return nil }
        return GoogleRoutesAPIService.evaluateBusQuery(busNumber, routes: [route])
    }

    private func refreshDestinationRoutesInBackgroundIfStale(
        busNumber: String,
        destination: Destination,
        originLatitude: Double,
        originLongitude: Double
    ) async {
        let now = Date()
        if let last = lastAutoTransitRoutesRefreshTime, now.timeIntervalSince(last) < 60 {
            return
        }
        lastAutoTransitRoutesRefreshTime = now

        let resolution = RoutesAPIKeyResolver.resolve(
            for: .transitRoutes(destinationID: destination.id),
            consumeTrial: false
        )
        guard let apiKey = resolution.apiKey else { return }

        let result = await GoogleRoutesAPIService.fetchTransitRoutes(
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destinationLatitude: destination.latitude,
            destinationLongitude: destination.longitude,
            apiKey: apiKey
        )
        guard !Task.isCancelled, enteredBusNumber == busNumber else { return }
        if case .success(let routes) = result {
            mergeIntoAccumulatedRoutes(routes)
        }
        guard !accumulatedTransitRoutes.isEmpty else { return }
        await evaluateAgainstAccumulatedRoutes(
            busNumber: busNumber,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destination: destination,
            allowNetworkAlternate: false,
            showCheckingWhileWaiting: false
        )
    }

    private func applyBusCheckResponse(_ response: BusCheckResponse, busNumber: String) {
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
        case .doNotBoard:
            applyResultState(.cannotBoard)
        case .noTransitRoutes:
            applyResultState(.noTransitRoutes)
        case .configurationError(let message), .apiError(let message):
            applyResultState(.error(message))
        }
        cacheCurrentBusCheck(for: busNumber)
    }

    private func cacheCurrentBusCheck(for busNumber: String) {
        switch resultState {
        case .idle, .checking:
            return
        default:
            break
        }
        busCheckCacheFingerprint = accumulatedRoutesFingerprint
        busCheckCache[busNumber] = BusCheckSnapshot(
            resultState: resultState,
            boardingRouteIndex: boardingRouteIndex,
            boardingRoute: boardingRoute,
            isBoardingRouteCheapest: isBoardingRouteCheapest
        )
    }

    private func applyResultState(
        _ state: ResultDisplayState,
        boardingRouteIndex: Int? = nil,
        boardingRoute: ParsedTransitRoute? = nil,
        isBoardingRouteCheapest: Bool = true
    ) {
        let previous = lastSettledResultState
        resultState = state
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

    func prepareBoardingRouteForVariant(_ variantName: String) {
        if let alternate = alternateBoardingRoutes[variantName]
            ?? alternateBoardingRoutes.first(where: { $0.key.caseInsensitiveCompare(variantName) == .orderedSame })?.value {
            boardingRoute = alternate
            return
        }
        if let match = GoogleRoutesAPIService.findMatchingRouteWithIndex(routes: accumulatedTransitRoutes, busNumber: variantName) {
            boardingRouteIndex = match.index
            boardingRoute = match.route
        }
    }

    private func rememberAlternateBoardingRoutes(from response: BusCheckResponse) {
        guard let route = response.matchingRoute else { return }
        if case .boardIfVariant(let names, _, _) = response.outcome {
            for name in names {
                alternateBoardingRoutes[name] = route
            }
        }
        if let index = response.matchingRouteIndex {
            boardingRouteIndex = index
        }
        alternateBoardingRoutes[enteredBusNumber] = route
        persistCurrentBucket()
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
        if let alternate = alternateBoardingRoutes[busNumber]
            ?? alternateBoardingRoutes.first(where: { $0.key.caseInsensitiveCompare(busNumber) == .orderedSame })?.value {
            boardingRoute = alternate
            let boardingLocationOverride: RouteCoordinate? = {
                guard let lat = currentLatitude, let lon = currentLongitude else { return nil }
                return RouteCoordinate(latitude: lat, longitude: lon)
            }()
            ridingTracker.buildRidingState(
                route: alternate,
                busNumber: busNumber,
                destination: destination,
                startTracking: ridingTracker.shouldTrackRiding,
                boardingLocationOverride: boardingLocationOverride
            )
            ridingTracker.enableLocationTrackingIfNeeded()
            syncEnteredBusNumber()
            return
        }
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

    private func clearRidingState() {
        ridingTracker.clear()
    }

    /// 降車のみを行う。clearBusNumber() と違い、バス番号入力欄・boardingRoute・
    /// 経路データベース・目的地には触れない。降り続けて別のバスへ乗り換える操作
    /// (長押しトグル・メイン画面の降車ボタン)から呼ぶ。
    func endRiding() {
        ridingTracker.endRiding()
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
