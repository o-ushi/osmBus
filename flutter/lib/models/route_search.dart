import '../services/geo.dart';
import 'bus_identifier.dart';
import 'route_catalog.dart';

/// 路線図の番号検索（Swift の `BusRouteMapView.startSearch`）。
/// Swift は Overpass に問い合わせるが、ここでは端末内の路線データから探す。
abstract final class RouteSearch {
  /// 入力した番号を含む形状付きの路線すべて（05 なら 05・5・E05・105 など）。
  /// 番号そのもの（系統違い・0 埋め違いを含む）を先に、番号を含むだけの路線を後に並べ、
  /// それぞれ近くに停留所がある順（現在地が無ければ番号順）。
  static List<RouteRecord> find(List<RouteRecord> routes, String input, {GeoPoint? near}) {
    final number = input.trim();
    if (number.isEmpty) return const [];
    final exact = <RouteRecord>[];
    final contains = <RouteRecord>[];
    for (final r in routes) {
      if (!r.hasGeometry || r.stops.isEmpty) continue;
      if (_matchesNumber(r.ref, number)) {
        exact.add(r);
      } else if (r.ref.toUpperCase().contains(number.toUpperCase())) {
        contains.add(r);
      }
    }
    return [..._sorted(exact, near), ..._sorted(contains, near)];
  }

  static List<RouteRecord> _sorted(List<RouteRecord> routes, GeoPoint? near) {
    if (near == null) {
      return routes..sort((a, b) => BusIdentifierParts.compareTokens(a.ref, b.ref));
    }
    final distance = {for (final r in routes) r.relationId: nearestStopMeters(r, near)};
    return routes..sort((a, b) => distance[a.relationId]!.compareTo(distance[b.relationId]!));
  }

  static bool _matchesNumber(String ref, String number) =>
      BusIdentifierParts.variants(number).any((v) => BusIdentifierParts.containsBusNumber(ref, v)) ||
      BusIdentifierParts.refMatchesCompactNumber(ref, number);

  static double nearestStopMeters(RouteRecord route, GeoPoint point) =>
      route.stops.map((s) => Geo.distance(s.point, point)).fold(double.infinity, (a, b) => a < b ? a : b);

  /// 一覧用。形状付きの路線を番号順に。
  static List<RouteRecord> listing(List<RouteRecord> routes) =>
      [for (final r in routes) if (r.hasGeometry && r.stops.isNotEmpty) r]
        ..sort((a, b) {
          final byRef = BusIdentifierParts.compareTokens(a.ref, b.ref);
          return byRef != 0 ? byRef : a.relationId.compareTo(b.relationId);
        });
}
