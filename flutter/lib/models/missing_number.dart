import '../services/geo.dart';
import '../services/local_planner.dart';
import 'route_catalog.dart';
import 'route_search.dart';

/// 番号表に無い番号を、この区間の停留所の位置で探す。
/// 出発地から [LocalPlanner.boardRadiusMeters] 以内の停留所と、
/// 目的地から [LocalPlanner.alightRadiusMeters] 以内の停留所が両方あれば、この区間の路線にする。
class MissingNumberResult {
  const MissingNumberResult({required this.onSegment, required this.numberOnly});

  final List<RouteRecord> onSegment;
  final List<RouteRecord> numberOnly;

  static const empty = MissingNumberResult(onSegment: [], numberOnly: []);
}

abstract final class MissingNumber {
  static MissingNumberResult find(
    List<RouteRecord> routes,
    String input, {
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final matches = RouteSearch.find(routes, input, near: origin);
    if (matches.isEmpty) return MissingNumberResult.empty;
    final onSegment = <RouteRecord>[];
    final numberOnly = <RouteRecord>[];
    for (final route in matches) {
      if (_coversSegment(route, origin, destination)) {
        onSegment.add(route);
      } else {
        numberOnly.add(route);
      }
    }
    return MissingNumberResult(onSegment: onSegment, numberOnly: numberOnly);
  }

  static bool _coversSegment(RouteRecord route, GeoPoint origin, GeoPoint destination) {
    var nearOrigin = false;
    var nearDestination = false;
    for (final stop in route.stops) {
      if (!nearOrigin && Geo.distance(stop.point, origin) <= LocalPlanner.boardRadiusMeters) {
        nearOrigin = true;
      }
      if (!nearDestination && Geo.distance(stop.point, destination) <= LocalPlanner.alightRadiusMeters) {
        nearDestination = true;
      }
      if (nearOrigin && nearDestination) return true;
    }
    return false;
  }
}
