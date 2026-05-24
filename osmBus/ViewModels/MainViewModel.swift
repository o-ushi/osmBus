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
    var enteredBusNumber = ""
    var resultState: ResultDisplayState = .idle

    var destinationLabel: String {
        destination?.name ?? AppLocaleString.currentText("目的地を設定")
    }

    var hasDestination: Bool {
        destination != nil
    }

    var hasCurrentLocation: Bool {
        currentLatitude != nil && currentLongitude != nil
    }

    var currentLocationCoordinateText: String? {
        guard let currentLatitude, let currentLongitude else { return nil }
        return AppLocaleString.currentFormatted(
            "osmBus_座標表示",
            String(format: "%.5f", currentLatitude),
            String(format: "%.5f", currentLongitude)
        )
    }

    enum ResultDisplayState: Equatable {
        case idle
        case checking
        case canBoard(arrivalText: String, alightStopText: String)
        case canBoardIfVariant(variantNames: [String], arrivalText: String, alightStopText: String)
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

    private(set) var transitRoutes: [ParsedTransitRoute] = []
    private(set) var transitRoutesLoadState: TransitRoutesLoadState = .idle

    private var busCheckTask: Task<Void, Never>?
    private var transitRoutesTask: Task<Void, Never>?
    private static let busCheckDebounceNanoseconds: UInt64 = 400_000_000
    private let resultHaptic = UINotificationFeedbackGenerator()

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

    func refreshTransitRoutes(userInitiated: Bool = false) {
        transitRoutesTask?.cancel()

        guard let destination, hasCurrentLocation,
              let currentLatitude, let currentLongitude else {
            resetTransitRoutes()
            return
        }

        let resolution = RoutesAPIKeyResolver.resolve(
            for: .transitRoutes(destinationID: destination.id),
            consumeTrial: userInitiated
        )
        guard let apiKey = resolution.apiKey else {
            switch resolution.unavailableReason {
            case .trialExhausted:
                transitRoutes = []
                transitRoutesLoadState = .failed(
                    AppLocaleString.currentText("osmBus_お試し枠_使い切り")
                )
            default:
                resetTransitRoutes()
            }
            return
        }

        transitRoutesLoadState = .loading

        transitRoutesTask = Task {
            let result = await GoogleRoutesAPIService.fetchTransitRoutes(
                originLatitude: currentLatitude,
                originLongitude: currentLongitude,
                destinationLatitude: destination.latitude,
                destinationLongitude: destination.longitude,
                apiKey: apiKey
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                switch result {
                case .success(let routes):
                    transitRoutes = routes
                    if routes.isEmpty {
                        transitRoutesLoadState = .failed(
                            AppLocaleString.currentText("osmBus_ルートなし")
                        )
                    } else {
                        transitRoutesLoadState = .loaded
                    }
                case .failure(let error):
                    transitRoutes = []
                    transitRoutesLoadState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func resetTransitRoutes() {
        transitRoutesTask?.cancel()
        transitRoutes = []
        transitRoutesLoadState = .idle
    }

    func appendBusCharacter(_ raw: String) {
        guard let character = BusNumberInput.normalizedCharacter(raw) else { return }

        if BusKeypadInputMode.current == .clearBeforeNewInput, hasSettledBusCheckResult {
            busCheckTask?.cancel()
            enteredBusNumber = ""
            resultState = .idle
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
    }

    func refreshBusCheck() {
        guard !enteredBusNumber.isEmpty else { return }
        scheduleBusCheck(immediate: true)
    }

    private func scheduleBusCheck(immediate: Bool = false) {
        busCheckTask?.cancel()

        guard !enteredBusNumber.isEmpty else {
            resultState = .idle
            return
        }

        busCheckTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: Self.busCheckDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await performBusCheck()
        }
    }

    @MainActor
    private func performBusCheck() async {
        resultState = .checking

        guard let destination else {
            applyResultState(.error(AppLocaleString.currentText("osmBus_エラー_目的地未設定")))
            return
        }

        guard let currentLatitude, let currentLongitude else {
            applyResultState(.error(AppLocaleString.currentText("osmBus_エラー_現在地未取得")))
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
                applyResultState(.error(AppLocaleString.currentText("osmBus_エラー_APIキー未設定")))
            }
            return
        }
        let outcome = await GoogleRoutesAPIService.checkBus(
            busNumber: busNumber,
            originLatitude: currentLatitude,
            originLongitude: currentLongitude,
            destination: destination,
            apiKey: apiKey
        )

        guard !Task.isCancelled, enteredBusNumber == busNumber else { return }

        switch outcome {
        case .boardAll(let arrivalText, let alightStopText):
            applyResultState(.canBoard(arrivalText: arrivalText, alightStopText: alightStopText))
        case .boardIfVariant(let names, let arrivalText, let alightStopText):
            applyResultState(.canBoardIfVariant(
                variantNames: names,
                arrivalText: arrivalText,
                alightStopText: alightStopText
            ))
        case .doNotBoard:
            applyResultState(.cannotBoard)
        case .noTransitRoutes:
            applyResultState(.noTransitRoutes)
        case .configurationError(let message), .apiError(let message):
            applyResultState(.error(message))
        }
    }

    private func applyResultState(_ state: ResultDisplayState) {
        resultState = state
        playResultHaptic(for: state)
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

// MARK: - Location

/// 現在地取得と権限状態の管理。
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var isUpdating = false
    @Published private(set) var lastError: String?

    private let manager = CLLocationManager()
    private var isOneShotActive = false
    private var locationTimeoutTask: Task<Void, Never>?

    private static let fetchTimeoutSeconds: UInt64 = 10

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = manager.authorizationStatus
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func refreshCurrentFromCache() {
        if let cached = manager.location {
            currentLocation = cached.coordinate
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
        isOneShotActive = false
        isUpdating = false
        manager.stopUpdatingLocation()
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
                manager.stopUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finishUpdating(withError: error.localizedDescription)
        }
    }
}
