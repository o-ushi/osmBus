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
    this.boardStopId,
    this.alightAdjusted = false,
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
      boardStopId: leg.boardStop.id,
      boardingDistanceToDestination:
          destination == null ? 0 : Geo.distance(leg.boardStop.point, destination),
    );
  }

  /// 路線図から乗った（Swift の `startFromOSMMap`）。降車は終点。
  /// 乗車停留所は、乗った時点の現在地 [position] に一番近い停留所（無ければ始発）。
  factory RidingSession.fromRoute(
    RouteRecord route, {
    required GeoPoint? destination,
    required DateTime now,
    GeoPoint? position,
  }) {
    final path = [for (final segment in route.polylineSegments) ...segment];
    final first = path.isNotEmpty ? path.first : route.stops.first.point;
    return RidingSession(
      ref: route.ref,
      alightStop: route.stops.last,
      path: path.isNotEmpty ? path : [for (final s in route.stops) s.point],
      startedAt: now,
      routeId: route.relationId,
      boardStopId: route.stops[nearestBoardIndex(route.stops, position)].id,
      boardingDistanceToDestination: destination == null ? 0 : Geo.distance(first, destination),
    );
  }

  /// [position] に一番近い停留所の添字。終点では乗らないので、終点の 1 つ手前まで。
  static int nearestBoardIndex(List<RouteStop> stops, GeoPoint? position) {
    if (position == null || stops.length < 2) return 0;
    var best = 0;
    for (var i = 1; i < stops.length - 1; i++) {
      if (Geo.distance(position, stops[i].point) < Geo.distance(position, stops[best].point)) best = i;
    }
    return best;
  }

  /// 降車停留所だけを [stop] に変えた乗車。乗車中の線は [path] にする。
  RidingSession withAlight(RouteStop stop, {required List<GeoPoint> path}) => RidingSession(
        ref: ref,
        alightStop: stop,
        path: path,
        startedAt: startedAt,
        itinerary: itinerary,
        legIndex: legIndex,
        routeId: routeId,
        boardStopId: boardStopId,
        alightAdjusted: true,
        boardingDistanceToDestination: boardingDistanceToDestination,
      );

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

  /// 乗車停留所の ID。降車停を ＋／− でずらすとき、これより手前には行かない。
  final int? boardStopId;

  /// 降車停を ＋／− で選び直したか。路線図から目的地なしで乗っても距離を出す。
  final bool alightAdjusted;

  /// 乗車地点から目的地までの直線距離。逆方向の検知に使う。0 なら検知しない。
  final double boardingDistanceToDestination;

  bool get fromRouteMap => itinerary == null;

  /// プロセスが殺されても同じ乗車に戻れるよう保存する形。
  Map<String, dynamic> toJson() => {
        'ref': ref,
        'alightStop': alightStop.toJson(),
        'path': [for (final p in path) [p.latitude, p.longitude]],
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (itinerary != null) 'itinerary': itinerary!.toJson(),
        'legIndex': legIndex,
        if (routeId != null) 'routeId': routeId,
        if (boardStopId != null) 'boardStopId': boardStopId,
        'alightAdjusted': alightAdjusted,
        'boardingDistanceToDestination': boardingDistanceToDestination,
      };

  factory RidingSession.fromJson(Map<String, dynamic> json) {
    final itinerary = json['itinerary'] as Map<String, dynamic>?;
    return RidingSession(
      ref: json['ref'] as String,
      alightStop: RouteStop.fromJson(json['alightStop'] as Map<String, dynamic>),
      path: pointsFromJson(json['path']),
      startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
      itinerary: itinerary == null ? null : LocalItinerary.fromJson(itinerary),
      legIndex: (json['legIndex'] as num?)?.toInt() ?? 0,
      routeId: (json['routeId'] as num?)?.toInt(),
      boardStopId: (json['boardStopId'] as num?)?.toInt(),
      alightAdjusted: json['alightAdjusted'] as bool? ?? false,
      boardingDistanceToDestination: (json['boardingDistanceToDestination'] as num?)?.toDouble() ?? 0,
    );
  }
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

  /// 乗車と一緒に保存し、復元後に同じリングを鳴らし直さない。
  Map<String, dynamic> toJson() => {
        'triggered': _triggered.toList()..sort(),
        if (_lastDistance != null) 'lastDistance': _lastDistance,
        'nearestReached': _nearestReached,
      };

  void restore(Map<String, dynamic> json) {
    reset();
    _triggered.addAll([for (final t in json['triggered'] as List? ?? const []) (t as num).toInt()]);
    _lastDistance = (json['lastDistance'] as num?)?.toDouble();
    _nearestReached = json['nearestReached'] as bool? ?? false;
  }

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
