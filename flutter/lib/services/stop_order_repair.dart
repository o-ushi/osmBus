import 'dart:math' as math;

import '../models/route_catalog.dart';

/// 停留所の並びを線に沿って並べ替える提案を作る。カタログの読み込み時には呼ばない。
/// ユーザーが「これを使う」を押したとき（保存はこの端末の中だけ）と、レビューの順序の所見を作るときに使う。
///
/// 各停留所を、その路線の線（way をメンバー順に繋いだもの）の一番近い位置へ落とし、線に沿った距離で測る。
/// メンバー順に見て、線から [onLineMeters] 以内の停留所が、それより前の停留所より線上で
/// [backtrackMeters] 以上戻っていれば並びは誤り。線から [onLineMeters] 以内の停留所だけを
/// 線に沿った順に並べ替え、離れた停留所は元の位置のまま残す。
/// 線が同じ場所を 2 度通っていても（終点のループなど）、一番近い位置で並べる。
abstract final class StopOrderRepair {
  static const double onLineMeters = 120;
  static const double backtrackMeters = 1000;

  /// 並びが明らかに逆行しているときだけ並べ替えた路線。そうでなければ [route] そのもの。
  ///
  /// 区間が端で繋がって一本になるときは、その線で測る。メンバー順の端は、途中で
  /// 折り返した記録になっていることがある。切れ目が離れているときは、これまで通り
  /// メンバー順に繋いで測る。
  /// [lowAlongFirst] が false のときは、線の終わり側を始点にする（方面の名前に合わせる）。
  static RouteRecord repair(RouteRecord route, {bool? lowAlongFirst}) {
    final stops = route.stops;
    if (stops.length < 3) return route;
    final chain = RouteLine.longestChain(route.polylineSegments);
    final connected = chain != null && _coversAll(route.polylineSegments, chain);
    final line = connected ? RouteLine.of([chain]) : RouteLine.of(route.polylineSegments);
    if (line == null) return route;

    final projections = [for (final stop in stops) line.project(stop.point)];
    if (!_backtracks(projections)) return route;

    final slots = [for (var i = 0; i < stops.length; i++) if (projections[i].onLine) i];
    final ordered = [...slots]..sort((a, b) {
        final along = projections[a].along.compareTo(projections[b].along);
        return along != 0 ? along : a.compareTo(b);
      });
    if (lowAlongFirst == false) {
      final flipped = ordered.reversed.toList();
      ordered
        ..clear()
        ..addAll(flipped);
    }
    final reordered = [...stops];
    for (var k = 0; k < slots.length; k++) {
      reordered[slots[k]] = stops[ordered[k]];
    }
    return route.copyWith(stops: reordered);
  }

  static bool _coversAll(List<List<GeoPoint>> segments, List<GeoPoint> chain) {
    bool near(GeoPoint point) {
      for (final vertex in chain) {
        if (RouteLine._snap(point, vertex)) return true;
      }
      return false;
    }

    for (final segment in segments) {
      if (segment.length < 2) continue;
      if (!near(segment.first) || !near(segment.last)) return false;
    }
    return true;
  }

  /// 線から近い停留所のうち、前の停留所より線上で [backtrackMeters] 以上戻っているものがあるか。
  static bool _backtracks(List<LineProjection> projections) {
    var furthest = double.negativeInfinity;
    for (final p in projections) {
      if (!p.onLine) continue;
      if (p.along < furthest - backtrackMeters) return true;
      furthest = math.max(furthest, p.along);
    }
    return false;
  }
}

/// 停留所を線へ落とした結果。
class LineProjection {
  const LineProjection({required this.along, required this.distance});

  /// 線の始まりから、停留所を落とした点までの線上の距離。
  final double along;

  /// 停留所から線までの距離。
  final double distance;

  bool get onLine => distance <= StopOrderRepair.onLineMeters;
}

/// メンバー順に繋いだ線。平面（その路線の始まりを原点にしたメートル）で測る。
/// 切れた way のあいだも長さは数えるが、停留所はそこへ落とさない。レビューの所見でも使う。
class RouteLine {
  RouteLine._(this._x, this._y, this._along, this._joins, this._lat0, this._lon0, this._lonScale);

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

  /// 端と端がこの距離以内なら、同じ点として繋ぐ。
  static const double snapMeters = 40;

  /// メンバー順ではなく、端が接している区間だけを一本に繋いだ、一番長い線。
  /// 接していない切れ目は別の線のままにし、都市を横切る飛びは作らない。
  static List<GeoPoint>? longestChain(List<List<GeoPoint>> segments) {
    final parts = [
      for (final segment in segments)
        if (segment.length >= 2) [...segment],
    ];
    if (parts.isEmpty) return null;
    final used = List<bool>.filled(parts.length, false);
    List<GeoPoint>? best;
    for (var i = 0; i < parts.length; i++) {
      if (used[i]) continue;
      final chain = [...parts[i]];
      used[i] = true;
      var grew = true;
      while (grew) {
        grew = false;
        for (var j = 0; j < parts.length; j++) {
          if (used[j]) continue;
          final other = parts[j];
          if (_snap(chain.last, other.first)) {
            chain.addAll(other.skip(1));
          } else if (_snap(chain.last, other.last)) {
            chain.addAll(other.reversed.skip(1));
          } else if (_snap(chain.first, other.last)) {
            chain.insertAll(0, other.take(other.length - 1));
          } else if (_snap(chain.first, other.first)) {
            chain.insertAll(0, other.reversed.take(other.length - 1));
          } else {
            continue;
          }
          used[j] = true;
          grew = true;
        }
      }
      if (best == null || chain.length > best.length) best = chain;
    }
    return best;
  }

  static bool _snap(GeoPoint a, GeoPoint b) {
    final lonScale = math.cos(a.latitude * math.pi / 180) * _metersPerDegreeLon;
    final dx = (b.longitude - a.longitude) * lonScale;
    final dy = (b.latitude - a.latitude) * _metersPerDegreeLat;
    return dx * dx + dy * dy <= snapMeters * snapMeters;
  }

  static RouteLine? of(List<List<GeoPoint>> segments) {
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
    return RouteLine._(x, y, along, joins, lat0, lon0, lonScale);
  }

  /// 線の一番近い位置。同じ距離なら線の手前の方。
  LineProjection project(GeoPoint point) {
    final px = (point.longitude - _lon0) * _lonScale;
    final py = (point.latitude - _lat0) * _metersPerDegreeLat;
    var bestDistance = double.infinity;
    var bestAlong = 0.0;
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
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong = along;
      }
    }
    return LineProjection(along: bestAlong, distance: bestDistance);
  }
}
