import 'dart:math' as math;

import 'route_catalog.dart';

/// 1 本のバスに乗る区間。
class ItineraryLeg {
  const ItineraryLeg({
    required this.relationId,
    required this.ref,
    required this.routeName,
    required this.boardIndex,
    required this.alightIndex,
    required this.boardStop,
    required this.alightStop,
    required this.path,
    required this.rideMeters,
  });

  final int relationId;
  final String ref;
  final String routeName;
  final int boardIndex;
  final int alightIndex;
  final RouteStop boardStop;
  final RouteStop alightStop;

  /// 乗車停留所から降車停留所までのポリライン。
  final List<GeoPoint> path;
  final double rideMeters;
}

/// 出発地から目的地までのローカル旅程（§8）。
class LocalItinerary {
  const LocalItinerary({
    required this.legs,
    required this.walkMeters,
    required this.bearing,
  });

  static const double walkSpeed = 1.25;
  static const double busSpeed = 5.56;

  final List<ItineraryLeg> legs;

  /// 出発地→乗車 + 乗換徒歩 + 降車→目的地。
  final double walkMeters;

  /// 第 1 レグの方位（度）。
  final double bearing;

  ItineraryLeg get firstLeg => legs.first;

  double get rideMeters => legs.fold(0.0, (sum, leg) => sum + leg.rideMeters);

  int get transferCount => legs.length - 1;

  /// 番号表の列。0 = 直通、1 = 乗換 1、2 = 乗換 2+。
  int get column => math.min(2, transferCount);

  int get compassIndex => ((bearing + 22.5) / 45).floor() % 8;

  /// 概算時間（分）。表示だけに使う。
  int get estimatedMinutes =>
      math.max(1, ((walkMeters / walkSpeed + rideMeters / busSpeed) / 60).round());

  /// 徒歩合計、同値なら乗車距離で比べる。
  static int compareByWalk(LocalItinerary a, LocalItinerary b) {
    final walk = a.walkMeters.compareTo(b.walkMeters);
    if (walk != 0) return walk;
    return a.rideMeters.compareTo(b.rideMeters);
  }
}
