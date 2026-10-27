import '../services/geo.dart';
import 'local_itinerary.dart';
import 'route_catalog.dart';

/// 乗車中の 1 本のバス（Swift の `RidingState` と `RidingTracker` の区間情報）。
class RidingSession {
  RidingSession({
    required this.ref,
    required this.alightStop,
    required this.path,
    required this.startedAt,
    this.itinerary,
    this.legIndex = 0,
    this.routeId,
    this.boardingDistanceToDestination = 0,
  });

  /// 番号表・判定から乗った。降車は [legIndex] 番目のレグの降車停留所（乗換があれば乗換地点）。
  factory RidingSession.fromItinerary(
    LocalItinerary itinerary, {
    int legIndex = 0,
    required GeoPoint? destination,
    required DateTime now,
  }) {
    final leg = itinerary.legs[legIndex];
    return RidingSession(
      ref: leg.ref,
      alightStop: leg.alightStop,
      path: leg.path,
      startedAt: now,
      itinerary: itinerary,
      legIndex: legIndex,
      boardingDistanceToDestination:
          destination == null ? 0 : Geo.distance(leg.boardStop.point, destination),
    );
  }

  /// 路線図から乗った（Swift の `startFromOSMMap`）。降車は終点。
  factory RidingSession.fromRoute(RouteRecord route, {required GeoPoint? destination, required DateTime now}) {
    final path = [for (final segment in route.polylineSegments) ...segment];
    final first = path.isNotEmpty ? path.first : route.stops.first.point;
    return RidingSession(
      ref: route.ref,
      alightStop: route.stops.last,
      path: path.isNotEmpty ? path : [for (final s in route.stops) s.point],
      startedAt: now,
      routeId: route.relationId,
      boardingDistanceToDestination: destination == null ? 0 : Geo.distance(first, destination),
    );
  }

  final String ref;
  final RouteStop alightStop;
  final List<GeoPoint> path;
  final DateTime startedAt;

  /// 番号表から乗ったときの旅程。路線図から乗ったときは null。
  final LocalItinerary? itinerary;

  /// [itinerary] のうち今乗っているレグ。乗り換えると進む。
  final int legIndex;

  /// 路線図から乗ったときの relation ID。
  final int? routeId;

  /// 乗車地点から目的地までの直線距離。逆方向の検知に使う。0 なら検知しない。
  final double boardingDistanceToDestination;

  bool get fromRouteMap => itinerary == null;
}

/// 距離アラートの発火（何 m のリングを越えたか、アラームを何回鳴らすか）。
class DistanceAlertFire {
  const DistanceAlertFire({required this.meters, required this.repeatCount, required this.isNearest});

  final int meters;

  /// 遠いリングから 1, 2, 3 回（Swift の `distanceAlarmCount`）。
  final int repeatCount;

  /// 有効なリングのうち一番近いもの。ここまで来たらバックグラウンド測位を止めてよい。
  final bool isNearest;
}

/// 降車地点へのリングを内向きに越えたときだけ鳴らす（Swift の `checkDistanceAlerts`）。
class DistanceAlertTracker {
  final Set<int> _triggered = {};
  double? _lastDistance;
  bool _nearestReached = false;

  bool get nearestReached => _nearestReached;

  void reset() {
    _triggered.clear();
    _lastDistance = null;
    _nearestReached = false;
  }

  /// [thresholds] は有効なリング（メートル）。同時に複数越えたら一番近い 1 つだけ鳴らす。
  DistanceAlertFire? update(double distance, List<int> thresholds) {
    final previous = _lastDistance;
    _lastDistance = distance;
    final sorted = [...thresholds]..sort((a, b) => b.compareTo(a));
    final crossed = <int>[];
    for (final threshold in sorted) {
      if (_triggered.contains(threshold) || distance > threshold) continue;
      // 追跡開始時点でリングの内側にいれば、そのリングも鳴らす。
      if (previous == null || previous > threshold) crossed.add(threshold);
    }
    if (crossed.isEmpty) return null;
    _triggered.addAll(crossed);
    final nearest = crossed.reduce((a, b) => a < b ? a : b);
    final isNearest = nearest == sorted.last;
    if (isNearest) _nearestReached = true;
    return DistanceAlertFire(
      meters: nearest,
      repeatCount: sorted.indexOf(nearest) + 1,
      isNearest: isNearest,
    );
  }
}

/// 逆方向に乗った疑い（Swift の `checkProgress`）。
/// 乗って 3 分以上経ち、路線の 15% も進んでおらず、目的地から乗車時の 1.5 倍以上離れたら true。
abstract final class WrongDirection {
  static const Duration grace = Duration(minutes: 3);

  static bool detect({
    required RidingSession session,
    required GeoPoint position,
    required GeoPoint? destination,
    required DateTime now,
  }) {
    if (destination == null || session.boardingDistanceToDestination <= 0) return false;
    if (now.difference(session.startedAt) <= grace) return false;
    final progress = session.path.isEmpty ? 0.0 : Geo.progressAlongPolyline(position, session.path);
    if (progress >= 0.15) return false;
    return Geo.distance(position, destination) > session.boardingDistanceToDestination * 1.5;
  }
}
