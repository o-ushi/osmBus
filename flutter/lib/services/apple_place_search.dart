import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/route_catalog.dart';
import 'app_log.dart';

/// Apple の地図検索が返した地点。
class ApplePlaceHit {
  const ApplePlaceHit(this.name, this.point, [this.subtitle]);

  final String name;
  final GeoPoint point;
  final String? subtitle;
}

/// 日本語の地名は OpenStreetMap に現地名しか無いことが多い。
/// iOS では Swift 版と同じ Apple の地図検索に任せる。
abstract final class ApplePlaceSearch {
  static const _channel = MethodChannel('osmbus/place_search');

  /// ひらがな、カタカナ、漢字。
  static final _japanese = RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uff66-\uff9d]');

  static bool containsJapanese(String query) => _japanese.hasMatch(query);

  /// 日本語を含み、iOS のときだけ探す。使えないときや失敗したときは null。
  static Future<List<ApplePlaceHit>?> search(String query, {GeoPoint? center}) async {
    if (kIsWeb || !containsJapanese(query) || !Platform.isIOS) return null;
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('search', {
        'query': query,
        if (center != null) 'latitude': center.latitude,
        if (center != null) 'longitude': center.longitude,
      });
      if (raw == null) return null;
      final places = <ApplePlaceHit>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name'] as String?;
        final lat = (item['latitude'] as num?)?.toDouble();
        final lon = (item['longitude'] as num?)?.toDouble();
        if (name == null || name.isEmpty || lat == null || lon == null) continue;
        places.add(ApplePlaceHit(name, GeoPoint(lat, lon), item['subtitle'] as String?));
      }
      return places;
    } on MissingPluginException {
      AppLog.w('search', 'apple place search channel missing (rebuild the native app)');
      return null;
    } on PlatformException catch (e) {
      AppLog.w('search', 'apple place search failed ${e.code}');
      return null;
    }
  }
}
