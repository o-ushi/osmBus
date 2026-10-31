import 'dart:math' as math;

import '../models/route_catalog.dart';

/// OSM の停留所メンバーの並びが走行順になっていない路線を、端末内でだけ直す。
/// OSM にも保存済みのカタログにも書き戻さない。読み込んだ [RouteRecord] を使う直前に一度だけ通す。
///
/// 各停留所を、その路線の線（way をメンバー順に繋いだもの）に沿った距離へ落とす。
/// メンバー順に見て、線から [onLineMeters] 以内の停留所が、それより前の停留所より線上で
/// [backtrackMeters] 以上戻っていれば並びは誤り。線から [onLineMeters] 以内の停留所だけを
/// 線に沿った順に並べ替え、離れた停留所は元の位置のまま残す。
/// 線がループしていて同じ停留所が 2 箇所に落ちるときは、どこに置くか決められないので直さない。
abstract final class StopOrderRepair {
  static const double onLineMeters = 120;
  static const double backtrackMeters = 1000;

  /// 同じ停留所の投影がこれ以上離れた 2 箇所にあれば、線が同じ場所を 2 度通っている。
  static const double revisitGapMeters = 500;

  /// 直した路線の数と、直したあとのスナップショット。直す路線が無ければ同じものを返す。
  static (CatalogSnapshot, int) snapshot(CatalogSnapshot snapshot) {
    var repaired = 0;
    final routes = <RouteRecord>[];
    for (final route in snapshot.routes) {
      final fixed = repair(route);
      if (!identical(fixed, route)) repaired++;
      routes.add(fixed);
    }
    if (repaired == 0) return (snapshot, 0);
    return (snapshot.copyWith(routes: routes), repaired);
  }

  /// 並びが明らかに逆行しているときだけ並べ替えた路線。そうでなければ [route] そのもの。
  static RouteRecord repair(RouteRecord route) {
    final stops = route.stops;
    if (stops.length < 3) return route;
    final line = _Line.of(route.polylineSegments);
    if (line == null) return route;

    final projections = [for (final stop in stops) line.project(stop.point)];
    if (!_backtracks(projections)) return route;
    if (projections.any((p) => p.onLine && p.revisits)) return route;

    final slots = [for (var i = 0; i < stops.length; i++) if (projections[i].onLine) i];
    final ordered = [...slots]..sort((a, b) {
        final along = projections[a].along.compareTo(projections[b].along);
        return along != 0 ? along : a.compareTo(b);
      });
    final reordered = [...stops];
    for (var k = 0; k < slots.length; k++) {
      reordered[slots[k]] = stops[ordered[k]];
    }
    return route.copyWith(stops: reordered);
  }

  /// 線から近い停留所のうち、前の停留所より線上で [backtrackMeters] 以上戻っているものがあるか。
  static bool _backtracks(List<_Projection> projections) {
    var furthest = double.negativeInfinity;
    for (final p in projections) {
      if (!p.onLine) continue;
      if (p.along < furthest - backtrackMeters) return true;
      furthest = math.max(furthest, p.along);
    }
    return false;
  }
}

class _Projection {
  const _Projection({required this.along, required this.distance, required this.revisits});

  /// 線の始まりから、停留所を落とした点までの線上の距離。
  final double along;

  /// 停留所から線までの距離。
  final double distance;

  /// 線から [StopOrderRepair.onLineMeters] 以内に落ちる場所が、離れて 2 箇所以上ある。
  final bool revisits;

  bool get onLine => distance <= StopOrderRepair.onLineMeters;
}

/// メンバー順に繋いだ線。平面（その路線の始まりを原点にしたメートル）で測る。
class _Line {
  _Line._(this._x, this._y, this._along, this._joins, this._lat0, this._lon0, this._lonScale);

  static const double _metersPerDegreeLat = 110574;
  static const double _metersPerDegreeLon = 111320;

  final List<double> _x;
  final List<double> _y;
  final List<double> _along;

  /// i → i+1 が way の切れ目を繋いだだけの辺か。長さは測るが、停留所は落とさない。
  final List<bool> _joins;
  final double _lat0;
  final double _lon0;
  final double _lonScale;

  static _Line? of(List<List<GeoPoint>> segments) {
    final points = <GeoPoint>[];
    final joins = <bool>[];
    for (final segment in segments) {
      for (var i = 0; i < segment.length; i++) {
        if (points.isNotEmpty) joins.add(i == 0);
        points.add(segment[i]);
      }
    }
    if (points.length < 2) return null;
    final lat0 = points.first.latitude;
    final lon0 = points.first.longitude;
    final lonScale = math.cos(lat0 * math.pi / 180) * _metersPerDegreeLon;
    final x = [for (final p in points) (p.longitude - lon0) * lonScale];
    final y = [for (final p in points) (p.latitude - lat0) * _metersPerDegreeLat];
    final along = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      along[i] = along[i - 1] + math.sqrt(math.pow(x[i] - x[i - 1], 2) + math.pow(y[i] - y[i - 1], 2));
    }
    return _Line._(x, y, along, joins, lat0, lon0, lonScale);
  }

  _Projection project(GeoPoint point) {
    final px = (point.longitude - _lon0) * _lonScale;
    final py = (point.latitude - _lat0) * _metersPerDegreeLat;
    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    final near = <double>[];
    for (var i = 0; i + 1 < _x.length; i++) {
      if (_joins[i]) continue;
      final dx = _x[i + 1] - _x[i];
      final dy = _y[i + 1] - _y[i];
      final length2 = dx * dx + dy * dy;
      final t = length2 == 0 ? 0.0 : (((px - _x[i]) * dx + (py - _y[i]) * dy) / length2).clamp(0.0, 1.0);
      final cx = _x[i] + t * dx;
      final cy = _y[i] + t * dy;
      final distance = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
      final along = _along[i] + t * (_along[i + 1] - _along[i]);
      if (distance <= StopOrderRepair.onLineMeters) near.add(along);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong = along;
      }
    }
    near.sort();
    var revisits = false;
    for (var k = 1; k < near.length; k++) {
      if (near[k] - near[k - 1] > StopOrderRepair.revisitGapMeters) revisits = true;
    }
    return _Projection(along: bestAlong, distance: bestDistance, revisits: revisits);
  }
}
