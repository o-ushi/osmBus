import CoreLocation
import Foundation

/// 現在地取得と権限状態の管理。
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var isUpdating = false
    @Published private(set) var lastError: String?

    private let manager = CLLocationManager()
    private var isOneShotActive = false
    private var isContinuousActive = false
    private var locationTimeoutTask: Task<Void, Never>?

    private static let fetchTimeoutSeconds: UInt64 = 10
    /// 目的地・降車地点までこの距離以内になったら高精度測位に切り替える。
    private static let nearTargetThresholdMeters: Double = 500
    private static let farAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    private static let nearAccuracy: CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters
    private static let farDistanceFilter: CLLocationDistance = 50
    private static let nearDistanceFilter: CLLocationDistance = 10

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = Self.farAccuracy
        manager.distanceFilter = Self.farDistanceFilter
        authorizationStatus = manager.authorizationStatus
    }

    /// 目的地・降車地点までの直線距離に応じて、GPSの精度と更新頻度を調整する。
    /// 遠いうちは低精度・低頻度にして消費電力を抑え、近づいたら高精度に戻す。
    func updateAccuracy(distanceToTargetMeters: Double?) {
        let isNear = (distanceToTargetMeters ?? .infinity) <= Self.nearTargetThresholdMeters
        let accuracy = isNear ? Self.nearAccuracy : Self.farAccuracy
        let filter = isNear ? Self.nearDistanceFilter : Self.farDistanceFilter
        if manager.desiredAccuracy != accuracy {
            manager.desiredAccuracy = accuracy
        }
        if manager.distanceFilter != filter {
            manager.distanceFilter = filter
        }
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func refreshCurrentFromCache() {
        if let cached = manager.location {
            currentLocation = cached.coordinate
        }
    }

    /// allowsBackground: バックグラウンドでも測位を続け、iOS の自動休止も無効にするか。
    /// 乗車中の距離アラートのように、画面を見ていない間も追跡が必須な場合のみ true にする。
    func startContinuousTracking(allowsBackground: Bool) {
        guard manager.authorizationStatus == .authorizedWhenInUse
           || manager.authorizationStatus == .authorizedAlways else { return }
        // 「使用中のみ」のままだと画面ロック中/バックグラウンドで測位が止まり、
        // 乗車中の距離アラートが発火しなくなる。「常に許可」への昇格をここで促す。
        // 既に常に許可済み、または「使用中のみ」以外の場合は iOS 側が何もしないので毎回呼んで問題ない。
        if allowsBackground, manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        manager.allowsBackgroundLocationUpdates = allowsBackground
        manager.pausesLocationUpdatesAutomatically = !allowsBackground
        guard !isContinuousActive else { return }
        isContinuousActive = true
        manager.startUpdatingLocation()
    }

    func stopContinuousTrackingAndDisableBackground() {
        manager.allowsBackgroundLocationUpdates = false
        stopContinuousTracking()
    }

    func stopContinuousTracking() {
        guard isContinuousActive else { return }
        isContinuousActive = false
        if !isOneShotActive {
            manager.stopUpdatingLocation()
        }
    }

    func fetchCurrentLocation() {
        lastError = nil
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isUpdating = false
            lastError = AppLocaleString.currentText("位置情報の利用が許可されていません。設定から許可してください。")
        case .authorizedAlways, .authorizedWhenInUse:
            if let cached = manager.location {
                currentLocation = cached.coordinate
            }
            guard !isOneShotActive else { return }
            isUpdating = true
            isOneShotActive = true
            manager.startUpdatingLocation()
            startFetchTimeout()
        @unknown default:
            isUpdating = false
            lastError = AppLocaleString.currentText("位置情報の状態を確認できません。")
        }
    }

    private func startFetchTimeout() {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: LocationService.fetchTimeoutSeconds * 1_000_000_000)
            guard let self, !Task.isCancelled, self.isOneShotActive else { return }
            self.finishUpdating(withError: AppLocaleString.currentText("位置情報を取得できませんでした。"))
        }
    }

    private func cancelFetchTimeout() {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
    }

    private func finishUpdating(withError error: String? = nil) {
        cancelFetchTimeout()
        if isOneShotActive {
            isOneShotActive = false
            isUpdating = false
            // 継続追跡中(乗車中など)はここで止めない。止めてしまうと isContinuousActive は
            // true のままなのに実体の測位だけ止まり、以後 startContinuousTracking が
            // 「既に有効」と判断して再開できず、現在地更新が復帰不能になる。
            if !isContinuousActive {
                manager.stopUpdatingLocation()
            }
        }
        if let error {
            lastError = error
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                fetchCurrentLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            cancelFetchTimeout()
            currentLocation = coordinate
            lastError = nil
            if isOneShotActive {
                isOneShotActive = false
                isUpdating = false
                if !isContinuousActive {
                    manager.stopUpdatingLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finishUpdating(withError: AppLocaleString.userFacingLocationError(error))
        }
    }
}
