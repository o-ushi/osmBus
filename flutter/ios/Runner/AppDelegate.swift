import Flutter
import GoogleMaps
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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GoogleMapsKey") {
      GoogleMapsKey.register(messenger: registrar.messenger())
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
