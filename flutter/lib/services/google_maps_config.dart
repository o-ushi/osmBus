import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';

/// 地図の背景を Google マップにするか（Swift 版の GMSServices）。
///
/// キーはネイティブ側が持つ。iOS は設定画面のキー（Swift 版と同じ Keychain 項目）か
/// ビルド時のキー、Android は manifest に入れたビルド時のキーだけ。
/// キーが無い・オフ・ネイティブ側が無い（テスト）ときは OSM の地図を使う。
class GoogleMapsConfig extends ChangeNotifier {
  GoogleMapsConfig._();

  static final GoogleMapsConfig instance = GoogleMapsConfig._();

  static const MethodChannel _channel = MethodChannel('osmbus/google_maps');
  static const _enabledKey = 'map.useGoogle';

  SharedPreferences? _prefs;
  String? _userKey;
  String? _bundledKey;
  String? _activeKey;
  bool _canEditKey = false;

  /// 設定画面で入れたキー（iOS のみ）。
  String? get userKey => _userKey;

  bool get hasBundledKey => _bundledKey != null;

  /// 設定画面でキーを変えられるか（iOS のみ）。
  bool get canEditKey => _canEditKey;

  /// 使うつもりのキー。設定画面のキーが優先。
  String? get configuredKey => _userKey ?? _bundledKey;

  bool get enabled => _prefs?.getBool(_enabledKey) ?? true;

  /// 保存したキーが、この起動で SDK に渡したキーと違う（再起動で反映）。
  bool get needsRestart => configuredKey != null && _activeKey != null && configuredKey != _activeKey;

  /// 地図を Google で描くか。SDK にキーを渡せていて、設定でも有効なとき。
  bool get useGoogle => enabled && configuredKey != null && _activeKey != null;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    await _apply(() => _channel.invokeMapMethod<String, Object?>('state'));
  }

  Future<void> setEnabled(bool value) async {
    await _prefs?.setBool(_enabledKey, value);
    notifyListeners();
  }

  /// 空文字・null で削除。
  Future<void> setUserKey(String? key) async {
    if (!_canEditKey) return;
    await _apply(() => _channel.invokeMapMethod<String, Object?>('setKey', key?.trim()));
  }

  Future<void> _apply(Future<Map<String, Object?>?> Function() call) async {
    try {
      final state = await call();
      if (state != null) {
        _userKey = state['userKey'] as String?;
        _bundledKey = state['bundledKey'] as String?;
        _activeKey = state['activeKey'] as String?;
        _canEditKey = state['canEditKey'] as bool? ?? false;
      }
    } on MissingPluginException {
      // テストなどネイティブ側が無いときは OSM のまま。ホットリスタートで古いネイティブ側に当たったときもここ。
      AppLog.w('map', 'google maps channel missing (rebuild the native app)');
    } catch (e) {
      AppLog.w('map', 'google maps key state failed $e');
    }
    AppLog.i('map', 'google maps ${useGoogle ? 'on' : 'off'} (key ${configuredKey == null ? 'none' : 'set'})');
    notifyListeners();
  }
}
