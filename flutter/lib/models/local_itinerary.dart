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

  Map<String, dynamic> toJson() => {
        'relationId': relationId,
        'ref': ref,
        'routeName': routeName,
        'boardIndex': boardIndex,
        'alightIndex': alightIndex,
        'boardStop': boardStop.toJson(),
        'alightStop': alightStop.toJson(),
        'path': [for (final p in path) [p.latitude, p.longitude]],
        'rideMeters': rideMeters,
      };

  factory ItineraryLeg.fromJson(Map<String, dynamic> json) => ItineraryLeg(
        relationId: (json['relationId'] as num).toInt(),
        ref: json['ref'] as String,
        routeName: json['routeName'] as String? ?? '',
        boardIndex: (json['boardIndex'] as num).toInt(),
        alightIndex: (json['alightIndex'] as num).toInt(),
        boardStop: RouteStop.fromJson(json['boardStop'] as Map<String, dynamic>),
        alightStop: RouteStop.fromJson(json['alightStop'] as Map<String, dynamic>),
        path: pointsFromJson(json['path']),
        rideMeters: (json['rideMeters'] as num).toDouble(),
      );
}

/// `[[緯度, 経度], …]`。
List<GeoPoint> pointsFromJson(Object? raw) => [
      for (final p in (raw as List? ?? const []).cast<List>())
        GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];

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

  Map<String, dynamic> toJson() => {
        'legs': [for (final leg in legs) leg.toJson()],
        'walkMeters': walkMeters,
        'bearing': bearing,
      };

  factory LocalItinerary.fromJson(Map<String, dynamic> json) => LocalItinerary(
        legs: [for (final leg in (json['legs'] as List).cast<Map<String, dynamic>>()) ItineraryLeg.fromJson(leg)],
        walkMeters: (json['walkMeters'] as num).toDouble(),
        bearing: (json['bearing'] as num).toDouble(),
      );

  double get rideMeters => legs.fold(0.0, (sum, leg) => sum + leg.rideMeters);

  int get transferCount => legs.length - 1;

  /// 同じ路線を同じ順に乗る旅程か。番号表は位置が変わるたびに作り直されるので、同一性ではこれで比べる。
  bool sameLegs(LocalItinerary other) {
    if (legs.length != other.legs.length) return false;
    for (var i = 0; i < legs.length; i++) {
      if (legs[i].relationId != other.legs[i].relationId) return false;
    }
    return true;
  }

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
