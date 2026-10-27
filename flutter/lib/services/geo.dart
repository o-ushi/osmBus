import 'dart:math' as math;

import '../models/route_catalog.dart';

/// Swift の `GoogleRoutesAPIService` と同じ地理計算。判定はここだけを使う。
abstract final class Geo {
  static const double earthRadiusMeters = 6371000;

  static double _rad(double deg) => deg * math.pi / 180;

  /// Haversine 距離（メートル）。
  static double distance(GeoPoint a, GeoPoint b) {
    final phi1 = _rad(a.latitude);
    final phi2 = _rad(b.latitude);
    final dPhi = _rad(b.latitude - a.latitude);
    final dLambda = _rad(b.longitude - a.longitude);
    final s1 = math.sin(dPhi / 2);
    final s2 = math.sin(dLambda / 2);
    final h = s1 * s1 + math.cos(phi1) * math.cos(phi2) * s2 * s2;
    return 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h)) * earthRadiusMeters;
  }

  /// 方位角（度、北 0、時計回り 0〜360）。
  static double bearing(GeoPoint from, GeoPoint to) {
    final phi1 = _rad(from.latitude);
    final phi2 = _rad(to.latitude);
    final dLambda = _rad(to.longitude - from.longitude);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// 隣接点間の距離の和。点が 2 未満なら 0。
  static double polylineLength(List<GeoPoint> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += distance(points[i - 1], points[i]);
    }
    return total;
  }

  /// 線上で [point] に一番近い位置が、始点から何割のところか（0〜1）。Swift の `progressAlongPolyline`。
  static double progressAlongPolyline(GeoPoint point, List<GeoPoint> polyline) {
    if (polyline.length < 2) return 0;
    final lengths = [for (var i = 1; i < polyline.length; i++) distance(polyline[i - 1], polyline[i])];
    final total = lengths.fold(0.0, (sum, l) => sum + l);
    if (total <= 0) return 0;
    var best = double.infinity;
    var progress = 0.0;
    var cumulative = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final dx = b.longitude - a.longitude;
      final dy = b.latitude - a.latitude;
      final lenSq = dx * dx + dy * dy;
      final t = lenSq < 1e-20
          ? 0.0
          : (((point.longitude - a.longitude) * dx + (point.latitude - a.latitude) * dy) / lenSq).clamp(0.0, 1.0);
      final d = distance(point, GeoPoint(a.latitude + t * dy, a.longitude + t * dx));
      if (d < best) {
        best = d;
        progress = (cumulative + t * lengths[i]) / total;
      }
      cumulative += lengths[i];
    }
    return progress;
  }

  /// 8 方位の添字。N, NE, E, SE, S, SW, W, NW の順。
  static int compassIndex(double bearing) =>
      ((bearing + 22.5) / 45).floor() % 8;

  /// 円周平均（度、0〜360）。
  static double circularMean(List<double> bearings) {
    var sinSum = 0.0;
    var cosSum = 0.0;
    for (final b in bearings) {
      sinSum += math.sin(_rad(b));
      cosSum += math.cos(_rad(b));
    }
    var mean = math.atan2(sinSum, cosSum) * 180 / math.pi;
    if (mean < 0) mean += 360;
    return mean;
  }

  /// 円周上で全方位角を含む最小弧の幅（度）。
  static double circularSpread(List<double> bearings) {
    if (bearings.length < 2) return 0;
    final sorted = bearings.map((b) => b % 360).toList()..sort();
    var largestGap = 360 - sorted.last + sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      largestGap = math.max(largestGap, sorted[i] - sorted[i - 1]);
    }
    return 360 - largestGap;
  }
}
