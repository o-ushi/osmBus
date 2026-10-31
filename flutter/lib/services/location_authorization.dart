import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';

/// iOS の「使用中のみ」を「常に許可」へ上げるよう求める（Swift の `requestAlwaysAuthorization()`）。
/// geolocator は許可が未決定のときしか尋ねないので、ネイティブ側で直接呼ぶ。
abstract final class LocationAuthorization {
  static const MethodChannel _channel = MethodChannel('osmbus/location_authorization');

  /// すでに常に許可、または使用中のみ以外なら iOS は何もしない。
  static Future<void> requestAlwaysIfWhenInUse() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status = await _channel.invokeMethod<String>('requestAlways');
      AppLog.i('location', 'always authorization status=$status');
    } catch (e) {
      AppLog.w('location', 'always authorization failed $e');
    }
  }
}
