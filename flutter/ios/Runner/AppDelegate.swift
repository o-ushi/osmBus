import CoreLocation
import Flutter
import GoogleMaps
import MapKit
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GoogleMapsKey.provideAtLaunch()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // 一度 SwiftUI.AppSceneDelegate で保存されたシーンは、Info.plist の
    // SceneDelegate を読まずに復元される。畳んだ外側画面はプロセスが生きたまま黒くなる。
    let configuration = UISceneConfiguration(
      name: connectingSceneSession.configuration.name ?? "flutter",
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = SceneDelegate.self
    configuration.storyboard = UIStoryboard(name: "Main", bundle: nil)
    return configuration
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GoogleMapsKey") {
      GoogleMapsKey.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlaceSearch") {
      PlaceSearch.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocationAuthorization") {
      LocationAuthorization.register(messenger: registrar.messenger())
    }
  }
}

/// 乗車開始で「使用中のみ」を「常に許可」へ上げるよう求める（Swift 版の `startContinuousTracking(allowsBackground:)` と同じ）。
/// 「使用中のみ」のままだと画面ロック中・バックグラウンドで測位が止まり、到着アラートが鳴らない。
enum LocationAuthorization {
  /// 問い合わせの間、マネージャを生かしておく。
  private static let manager = CLLocationManager()

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "osmbus/location_authorization", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "requestAlways" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let status = manager.authorizationStatus
      // すでに常に許可、または使用中のみ以外なら何もしない。
      if status == .authorizedWhenInUse {
        manager.requestAlwaysAuthorization()
      }
      result(name(of: status))
    }
  }

  private static func name(of status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "whenInUse"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }
}

/// Google Maps SDK の API キー。設定画面のキーは Swift 版と同じ Keychain 項目に置くので、
/// Swift 版で保存したキーもそのまま使える。無ければビルド時のキー（Info.plist の GoogleMapsAPIKey）。
enum GoogleMapsKey {
  private static let keychainAccount = "google.apiKey.userOverride"

  /// この起動で SDK に渡したキー。SDK は起動中にキーを差し替えられないので、最初の 1 回だけ渡す。
  private static var activeKey: String?

  static var bundledKey: String? {
    nonEmpty(Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String)
  }

  static func provideAtLaunch() {
    provideIfNeeded(userKey() ?? bundledKey)
  }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "osmbus/google_maps", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "state":
        result(state())
      case "setKey":
        setUserKey(call.arguments as? String)
        provideIfNeeded(userKey() ?? bundledKey)
        result(state())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func state() -> [String: Any?] {
    ["userKey": userKey(), "bundledKey": bundledKey, "activeKey": activeKey, "canEditKey": true]
  }

  private static func provideIfNeeded(_ key: String?) {
    guard activeKey == nil, let key else { return }
    if GMSServices.provideAPIKey(key) { activeKey = key }
  }

  private static func nonEmpty(_ raw: String?) -> String? {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  // MARK: - Keychain（Swift 版の KeychainStore と同じ項目）

  private static var baseQuery: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: keychainAccount]
  }

  static func userKey() -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return nonEmpty(String(data: data, encoding: .utf8))
  }

  private static func setUserKey(_ raw: String?) {
    guard let key = nonEmpty(raw) else {
      SecItemDelete(baseQuery as CFDictionary)
      return
    }
    let data = Data(key.utf8)
    if SecItemCopyMatching(baseQuery as CFDictionary, nil) == errSecSuccess {
      SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    } else {
      var item = baseQuery
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
      SecItemAdd(item as CFDictionary, nil)
    }
  }
}

/// 日本語の地名。OpenStreetMap には現地名しか無いことが多いので、Swift 版と同じく Apple の地図検索を使う。
enum PlaceSearch {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "osmbus/place_search", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "search",
            let args = call.arguments as? [String: Any],
            let query = args["query"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let center: CLLocationCoordinate2D? = {
        // Flutter の数値は NSNumber で届く。
        guard let lat = (args["latitude"] as? NSNumber)?.doubleValue,
              let lon = (args["longitude"] as? NSNumber)?.doubleValue else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
      }()
      Task { @MainActor in
        do {
          result(try await search(query, near: center))
        } catch {
          result(FlutterError(code: "search_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func search(_ query: String, near center: CLLocationCoordinate2D?) async throws -> [[String: Any]] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = [.address, .pointOfInterest]
    if let center {
      // 範囲の指定は優先のヒント。遠い候補も残る。
      request.region = MKCoordinateRegion(
        center: center,
        span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
      )
    }
    let response = try await MKLocalSearch(request: request).start()
    return response.mapItems.prefix(10).compactMap { item in
      let coordinate = item.placemark.coordinate
      guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
      var row: [String: Any] = [
        "name": item.name ?? item.placemark.name ?? query,
        "latitude": coordinate.latitude,
        "longitude": coordinate.longitude,
      ]
      if let subtitle = subtitle(for: item.placemark) {
        row["subtitle"] = subtitle
      }
      return row
    }
  }

  private static func subtitle(for placemark: MKPlacemark) -> String? {
    let parts = [placemark.thoroughfare, placemark.subLocality, placemark.locality, placemark.administrativeArea]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }
}
