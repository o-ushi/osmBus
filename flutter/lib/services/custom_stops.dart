import '../models/route_catalog.dart';

/// ユーザーが直した停留所の記憶（`stopOrder.applied` の 1 路線分）を、今の OSM の路線に合わせて整える。
/// 記憶の正本はこの端末の `SharedPreferences`。カタログのファイルと OSM には書き戻さない。
/// バックアップと iCloud の個人データには、場所・履歴と一緒に載せる。
///
/// 読めるのは 2 つの形。
/// - これまでの形: 停留所 ID の配列。その路線の停留所 ID の並べ替えのときだけ使い、名前と座標は OSM のもの。
/// - 新しい形: 停留所（`id`, `name`, `latitude`, `longitude`）の配列。
///
/// 新しい形の要素は次のように整える。
/// - `id` が正で、今の OSM のその路線にある: 名前は OSM、座標は覚えたもの。
/// - `id` が正で、その路線には無いが、カタログの他の路線にある（場所の差し替えや「停留所を足す」で
///   ユーザーが選んだ既存の停留所）: 名前はその OSM の停留所、座標は覚えたもの。
/// - `id` が正で、OSM から消えた: 落とす。
/// - `id` が負: ユーザーが足した停留所。名前も座標も覚えたもの。
/// 整えた結果が 2 件未満なら記憶は捨てる。
abstract final class CustomStops {
  static const int minStops = 2;

  /// 表示に使う停留所。記憶を捨てるべきときは null。
  /// [elsewhere] はカタログの他の路線の停留所（ID → 停留所）。
  static List<RouteStop>? resolve(RouteRecord osm, Object? remembered, {Map<int, RouteStop> elsewhere = const {}}) {
    if (remembered is! List || remembered.isEmpty) return null;
    if (remembered.every((e) => e is num)) {
      return _fromIds(osm, [for (final e in remembered) (e as num).toInt()]);
    }
    if (remembered.every((e) => e is Map)) {
      return _fromStops(osm, remembered.cast<Map>(), elsewhere);
    }
    return null;
  }

  /// 新しい形で保存する値。
  static List<Map<String, Object>> encode(List<RouteStop> stops) => [
        for (final s in stops) {'id': s.id, 'name': s.name, 'latitude': s.latitude, 'longitude': s.longitude},
      ];

  static List<RouteStop>? _fromIds(RouteRecord osm, List<int> ids) {
    final stops = osm.stops;
    if (ids.length != stops.length) return null;
    final byId = {for (final s in stops) s.id: s};
    if (byId.length != stops.length) return null;
    if (ids.toSet().length != ids.length) return null;
    final out = <RouteStop>[];
    for (final id in ids) {
      final stop = byId[id];
      if (stop == null) return null;
      out.add(stop);
    }
    return out.length < minStops ? null : out;
  }

  static List<RouteStop>? _fromStops(RouteRecord osm, List<Map> remembered, Map<int, RouteStop> elsewhere) {
    final byId = {for (final s in osm.stops) s.id: s};
    final out = <RouteStop>[];
    for (final raw in remembered) {
      final RouteStop stop;
      try {
        stop = RouteStop.fromJson(raw.cast<String, dynamic>());
      } catch (_) {
        continue;
      }
      if (stop.id > 0) {
        final current = byId[stop.id] ?? elsewhere[stop.id];
        if (current == null) continue;
        out.add(RouteStop(id: stop.id, name: current.name, latitude: stop.latitude, longitude: stop.longitude));
      } else if (stop.id < 0) {
        out.add(stop);
      }
    }
    return out.length < minStops ? null : out;
  }
}
