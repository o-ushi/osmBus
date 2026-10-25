import CoreLocation
import Foundation
import Observation
import UIKit
import UserNotifications
import os.log

/// 乗車中に表示する UI アラート。毎回 UUID を振り直し、SwiftUI が確実に再表示できるようにする。
struct ActiveRidingAlert: Identifiable, Equatable {
    enum Kind: Equatable {
        case distance(meters: Int)
    }

    let id: UUID
    let kind: Kind

    init(kind: Kind) {
        self.id = UUID()
        self.kind = kind
    }
}

/// 乗車中の進捗追跡・アラート・OSM 連携を担当。
@MainActor
@Observable
final class RidingTracker {
    private(set) var ridingState: RidingState?
    private(set) var shouldTrackRiding = false
    private(set) var isOSMMapRiding = false
    private(set) var osmRidingRouteCandidate: BusRouteCandidate?
    private(set) var osmRidingRouteDetail: BusRouteDetail?
    private(set) var wrongDirectionDetected = false
    /// 有効な距離アラートのうち最も近いリング(ゴール直前)まで到達したか。
    /// 降車ボタンの押し忘れでバックグラウンド測位が延々と続き、端末が発熱するのを
    /// 防ぐため、ここが true になったら呼び出し側でバックグラウンド追跡を止める。
    private(set) var nearestDistanceAlertReached = false
    private(set) var activeAlert: ActiveRidingAlert?
    /// activeAlert 表示中に発火した分。前のアラートが閉じられ次第、順番に表示する。
    private var pendingRidingAlerts: [ActiveRidingAlert] = []

    private static let logger = Logger(subsystem: "com.osamushikubo.osmBus", category: "RidingTracker")

    private var ridingRoutePolyline: [RouteCoordinate] = []
    private var ridingStartTime: Date?
    private var boardingStopDistanceToDestination: Double = 0
    /// 直近に乗車した区間の steps インデックス。乗り換え(降車→次のバスへ乗車)の際、
    /// 既に降りたレグへ再マッチしないようにするための手がかり。endRiding() では
    /// 保持し、clear() で完全リセットする。
    private var lastBoardedStepIndex: Int?

    /// 降車バス停（直線距離の基準点）
    private(set) var alightCoordinate: CLLocationCoordinate2D?
    /// 距離アラートを鳴らし済みの閾値（メートル）
    private var triggeredDistanceThresholds: Set<Int> = []
    /// 前回位置更新時の降車地点までの直線距離
    private var lastDistanceToAlight: Double?

    var isActive: Bool { ridingState != nil }

    func clear() {
        endRiding()
        lastBoardedStepIndex = nil
    }

    /// 乗車状態だけを終了する。バス番号入力・経路データベース・目的地には触れない
    /// (呼び出し元の MainViewModel 側で保持される)。lastBoardedStepIndex も保持し、
    /// 続けて次のバスへ乗る際に既に降りたレグへ再マッチしないようにする。
    /// 新しい旅の開始など、完全リセットしたい場合は clear() を使う。
    func endRiding() {
        ridingState = nil
        isOSMMapRiding = false
        osmRidingRouteCandidate = nil
        osmRidingRouteDetail = nil
        ridingRoutePolyline = []
        shouldTrackRiding = false
        ridingStartTime = nil
        boardingStopDistanceToDestination = 0
        wrongDirectionDetected = false
        nearestDistanceAlertReached = false
        activeAlert = nil
        pendingRidingAlerts = []
        alightCoordinate = nil
        triggeredDistanceThresholds = []
        lastDistanceToAlight = nil
    }

    func buildRidingState(
        route: ParsedTransitRoute?,
        busNumber: String,
        destination: Destination?,
        startTracking: Bool,
        boardingLocationOverride: RouteCoordinate? = nil,
        advancePastPreviousLeg: Bool = true
    ) {
        guard let route else { clear(); return }

        guard let busStepIdx = Self.resolveBusStepIndex(
            in: route.steps,
            busNumber: busNumber,
            afterStepIndex: lastBoardedStepIndex,
            advancePastPreviousLeg: advancePastPreviousLeg
        ) else {
            clear()
            return
        }
        lastBoardedStepIndex = busStepIdx
        let busStep = route.steps[busStepIdx]
        let alightStop = busStep.arrivalStopName ?? destination?.name ?? ""

        ridingRoutePolyline = busStep.polylineCoordinates
        shouldTrackRiding = startTracking && !ridingRoutePolyline.isEmpty
        isOSMMapRiding = false
        osmRidingRouteCandidate = nil
        osmRidingRouteDetail = nil

        // 現在乗車中のバスレグのみ対象（将来の乗継バスは含めない）
        configureAlightCoordinate(
            Self.resolveAlightCoordinate(for: busStep, destination: destination)
        )
        // 乗車中に別区間のバスへ切り替えた場合、その区間の出発停留所は実際に乗った場所とは
        // 限らない(手前の停留所で既に乗り換え済みのことがある)。その場合は現在地を基準にする。
        let boardingPoint = boardingLocationOverride ?? busStep.departureStopLocation ?? busStep.polylineCoordinates.first
        if let boarding = boardingPoint, let dest = destination {
            boardingStopDistanceToDestination = Self.coordinateDistance(
                from: CLLocationCoordinate2D(latitude: boarding.latitude, longitude: boarding.longitude),
                to: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
            )
        }
        ridingStartTime = Date()
        wrongDirectionDetected = false

        ridingState = RidingState(
            busNumber: busNumber,
            alightStopName: alightStop
        )
    }

    func enableLocationTrackingIfNeeded() {
        guard ridingState != nil else { return }
        shouldTrackRiding = !ridingRoutePolyline.isEmpty
    }

    func startFromOSMMap(
        routeRef: String,
        candidate: BusRouteCandidate,
        routeDetail: BusRouteDetail?,
        destination: Destination?
    ) {
        configureAlightCoordinate(Self.resolveOSMAlightCoordinate(routeDetail: routeDetail, destination: destination))
        ridingRoutePolyline = (routeDetail?.polylineSegments ?? []).flatMap { segment in
            segment.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }
        shouldTrackRiding = false
        ridingStartTime = Date()
        wrongDirectionDetected = false
        if let boardingPoint = ridingRoutePolyline.first, let dest = destination {
            boardingStopDistanceToDestination = Self.coordinateDistance(
                from: CLLocationCoordinate2D(latitude: boardingPoint.latitude, longitude: boardingPoint.longitude),
                to: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
            )
        } else {
            boardingStopDistanceToDestination = 0
        }
        ridingState = RidingState(
            busNumber: routeRef,
            alightStopName: destination?.name ?? ""
        )
        isOSMMapRiding = true
        osmRidingRouteCandidate = candidate
        osmRidingRouteDetail = routeDetail
    }

    func updateRouteWhileRiding(
        route: ParsedTransitRoute?,
        busNumber: String,
        destination: Destination?
    ) {
        guard let state = ridingState else { return }
        let ridingBus = state.busNumber
        guard let route,
              route.steps.contains(where: { step in
                  step.travelMode == "TRANSIT" &&
                  step.vehicleType == "BUS" &&
                  GoogleRoutesAPIService.stepMatchesBusNumber(step, busNumber: ridingBus)
              })
        else {
            // ルートに乗車中バスが含まれない → 距離アラームを抑制
            // 既に発火済みの閾値とポリラインは保持しておく
            alightCoordinate = nil
            return
        }
        buildRidingState(
            route: route,
            busNumber: ridingBus,
            destination: destination,
            startTracking: shouldTrackRiding,
            // 同じバスに乗ったまま経路を差し替えるときは、次の同番号区間へ飛ばさない。
            // 飛ばすと乗換地点ではなくゴール側が降車地点になり、近づいても距離が減らない。
            advancePastPreviousLeg: false
        )
    }

    /// 降車地点が欠けている、または今のバス区間の線から外れているときに付け直す。
    /// 乗車中の位置更新ごとに呼び、乗換前の残り距離と到着アラートの基準を区間の終わりに保つ。
    func realignAlightWithRoute(
        _ route: ParsedTransitRoute?,
        busNumber: String,
        destination: Destination?
    ) {
        guard ridingState != nil, let route else { return }
        let matchesRidingBus = route.steps.contains { step in
            step.travelMode == "TRANSIT" &&
            step.vehicleType == "BUS" &&
            GoogleRoutesAPIService.stepMatchesBusNumber(step, busNumber: busNumber)
        }
        guard matchesRidingBus else { return }
        guard let busStepIdx = Self.resolveBusStepIndex(
            in: route.steps,
            busNumber: busNumber,
            afterStepIndex: lastBoardedStepIndex,
            advancePastPreviousLeg: false
        ) else { return }

        let busStep = route.steps[busStepIdx]
        if ridingRoutePolyline.isEmpty {
            ridingRoutePolyline = busStep.polylineCoordinates
            if !ridingRoutePolyline.isEmpty {
                shouldTrackRiding = true
            }
        }
        configureAlightCoordinate(
            Self.resolveAlightCoordinate(for: busStep, destination: destination)
        )
    }

    func dismissWrongDirection() {
        wrongDirectionDetected = false
    }

    func dismissActiveAlert() {
        activeAlert = nil
        guard !pendingRidingAlerts.isEmpty else { return }
        let next = pendingRidingAlerts.removeFirst()
        // SwiftUI の .alert(item:) は表示中に item を差し替えても再表示されないため、
        // 前のアラートが閉じ切ってから次を提示する。
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self?.activeAlert = next
        }
    }

    func checkProgress(at coordinate: CLLocationCoordinate2D, destination: Destination?) {
        guard ridingState != nil else { return }

        if !wrongDirectionDetected,
           boardingStopDistanceToDestination > 0,
           let startTime = ridingStartTime,
           Date().timeIntervalSince(startTime) > 180,
           let dest = destination {
            let routeProgress = ridingRoutePolyline.isEmpty ? 0.0 : GoogleRoutesAPIService.progressAlongPolyline(
                (latitude: coordinate.latitude, longitude: coordinate.longitude),
                ridingRoutePolyline
            )
            // ルートの15%以上進んでいる場合は正しい方向と判断して検知しない
            if routeProgress < 0.15 {
                let distanceToDestination = Self.coordinateDistance(
                    from: coordinate,
                    to: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                )
                if distanceToDestination > boardingStopDistanceToDestination * 1.5 {
                    wrongDirectionDetected = true
                }
            }
        }

        checkDistanceAlerts(at: coordinate)
    }

    private func configureAlightCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else {
            alightCoordinate = nil
            triggeredDistanceThresholds = []
            lastDistanceToAlight = nil
            nearestDistanceAlertReached = false
            return
        }
        if let current = alightCoordinate {
            let drift = Self.coordinateDistance(from: current, to: coordinate)
            if drift < 5 { return }
            if drift < 30 {
                alightCoordinate = coordinate
                return
            }
        }
        alightCoordinate = coordinate
        triggeredDistanceThresholds = []
        lastDistanceToAlight = nil
        nearestDistanceAlertReached = false
    }

    /// busNumber に一致するバス区間の steps インデックスを選ぶ。同じルート内に同じ番号の
    /// レグが複数ある場合(乗り換えて再び同じ路線に乗る等)、afterStepIndex より後ろの
    /// レグを優先し、既に降りたレグへ再マッチしないようにする。該当が無ければ最初の
    /// 一致を使い、番号自体が見つからなければ最初のバス区間にフォールバックする。
    private static func resolveBusStepIndex(
        in steps: [ParsedTransitStep],
        busNumber: String,
        afterStepIndex: Int?,
        advancePastPreviousLeg: Bool = true
    ) -> Int? {
        let matchingIndices = steps.indices.filter { idx in
            let step = steps[idx]
            return step.travelMode == "TRANSIT" &&
                step.vehicleType == "BUS" &&
                GoogleRoutesAPIService.stepMatchesBusNumber(step, busNumber: busNumber)
        }
        guard !matchingIndices.isEmpty else {
            return steps.firstIndex { step in
                step.travelMode == "TRANSIT" && step.vehicleType == "BUS"
            }
        }
        if !advancePastPreviousLeg, let afterStepIndex, matchingIndices.contains(afterStepIndex) {
            return afterStepIndex
        }
        if advancePastPreviousLeg, let afterStepIndex, let next = matchingIndices.first(where: { $0 > afterStepIndex }) {
            return next
        }
        return matchingIndices.first
    }

    private static func resolveAlightCoordinate(
        for busStep: ParsedTransitStep,
        destination: Destination?
    ) -> CLLocationCoordinate2D? {
        GoogleRoutesAPIService.legAlightCoordinate(
            arrival: busStep.arrivalStopLocation,
            polyline: busStep.polylineCoordinates,
            fallbackLatitude: destination?.latitude,
            fallbackLongitude: destination?.longitude
        )
    }

    private static func resolveOSMAlightCoordinate(
        routeDetail: BusRouteDetail?,
        destination: Destination?
    ) -> CLLocationCoordinate2D? {
        if let lastStop = routeDetail?.stops.last {
            return lastStop.coordinate
        }
        if let destination {
            return CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        }
        return nil
    }

    /// 乗車機能内の距離計算はすべてこのヘルパー経由にし、CLLocation の生成箇所を1箇所に絞る。
    private static func coordinateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        GoogleRoutesAPIService.distanceMeters(
            fromLatitude: from.latitude,
            fromLongitude: from.longitude,
            toLatitude: to.latitude,
            toLongitude: to.longitude
        )
    }

    private func checkDistanceAlerts(at coordinate: CLLocationCoordinate2D) {
        guard ridingState != nil else { return }
        guard let alightCoordinate else { return }

        let distance = Self.coordinateDistance(from: coordinate, to: alightCoordinate)
        let previousDistance = lastDistanceToAlight
        lastDistanceToAlight = distance

        let thresholds = DistanceAlertSlot.all
            .filter(\.isEnabled)
            .map(\.meters)
            .sorted(by: >)

        var crossedThresholds: [Int] = []
        for threshold in thresholds {
            guard !triggeredDistanceThresholds.contains(threshold) else { continue }
            let limit = Double(threshold)
            guard distance <= limit else { continue }

            let crossedInward: Bool
            if let previousDistance {
                crossedInward = previousDistance > limit
            } else {
                // 追跡開始時点ですでにリング内にいる場合は、そのリング分を鳴らす
                crossedInward = true
            }
            guard crossedInward else { continue }

            crossedThresholds.append(threshold)
        }

        guard !crossedThresholds.isEmpty else { return }
        triggeredDistanceThresholds.formUnion(crossedThresholds)

        // GPSが一瞬途切れて再取得した直後など、1回の更新で複数のリングを同時に
        // 通過することがある。全リング分を個別に鳴らすと再生が重なって回数が
        // ずれて聞こえ、画面アラートも複数件キューされて降車確認アラートが
        // 割り込めなくなる(SwiftUIは複数の.alertを同時提示できない)。
        // 一番近い(＝最重要)リング1件分だけを鳴らし、他は「発火済み」扱いにして
        // 後から重複して鳴らないようにする。
        if let nearest = crossedThresholds.min() {
            Self.logger.notice("checkDistanceAlerts crossed multiple thresholds at once: \(crossedThresholds), firing nearest=\(nearest)")
            triggerDistanceAlert(meters: nearest)
            // 有効な距離アラートのうち一番近いリング(ゴール直前)に到達したら、以後の
            // バックグラウンド測位継続の要否は呼び出し側(降車ボタンの押し忘れ対策)に委ねる。
            if nearest == thresholds.min() {
                nearestDistanceAlertReached = true
            }
        }
    }

    private func triggerDistanceAlert(meters: Int) {
        let playAlarm = StopAlertSettings.isEnabled(.alarm)
        let playVibration = StopAlertSettings.isEnabled(.vibration)
        Self.logger.notice("triggerDistanceAlert meters=\(meters) playAlarm=\(playAlarm) playVibration=\(playVibration)")
        if playAlarm {
            StopAlertPlayer.shared.playAlarmTimes(distanceAlarmCount(for: meters))
        }
        if playVibration {
            StopAlertPlayer.shared.playVibration()
        }
        if playAlarm || playVibration || StopAlertSettings.isEnabled(.alert) {
            presentAlert(.distance(meters: meters))
        }
    }

    /// 有効な距離スロットを遠い順に並べ、meters が何番目か（1始まり）を返す。
    /// 1番遠い→1回、2番目→2回、3番目（最近）→3回
    private func distanceAlarmCount(for meters: Int) -> Int {
        let sorted = DistanceAlertSlot.all
            .filter { $0.isEnabled }
            .sorted { $0.meters > $1.meters }  // 遠い順
        guard let rank = sorted.firstIndex(where: { $0.meters == meters }) else { return 1 }
        return rank + 1
    }

    func overrideBusNumber(_ newBusNumber: String) {
        guard ridingState != nil else { return }
        ridingState?.busNumber = newBusNumber
    }

    private func presentAlert(_ kind: ActiveRidingAlert.Kind) {
        if UIApplication.shared.applicationState == .active {
            let alert = ActiveRidingAlert(kind: kind)
            if activeAlert == nil {
                activeAlert = alert
            } else {
                pendingRidingAlerts.append(alert)
            }
            return
        }
        switch kind {
        case .distance(let meters):
            postLocalNotification(
                title: AppLocaleString.currentText("距離アラート_タイトル"),
                body: AppLocaleString.currentFormatted("距離アラート_%d", meters)
            )
        }
    }

    private func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // アラーム音・バイブレーションは StopAlertPlayer が既に再生済み（表・裏とも共通）。
        // ここでサウンドを付けると通知既定音が二重に鳴り、表と鳴り方が変わってしまう。
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
