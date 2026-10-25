import 'package:osmbus/models/route_catalog.dart';

/// 約 1km（緯度 0.009 度）。
const double kmLat = 0.009;

/// 約 100m。
const double hundredMetersLat = 0.0009;

RouteRecord route({
  required int id,
  required String ref,
  required List<GeoPoint> stops,
  bool withPolyline = true,
}) {
  return RouteRecord(
    relationId: id,
    ref: ref,
    name: 'Route $ref',
    stops: [
      for (var i = 0; i < stops.length; i++)
        RouteStop(
          id: id * 100 + i,
          name: '$ref-stop$i',
          latitude: stops[i].latitude,
          longitude: stops[i].longitude,
        ),
    ],
    polylineSegments: withPolyline ? [stops] : const [],
    hasGeometry: true,
  );
}

/// 経度 [lon] で北へ 1km 間隔の停留所 [count] 個。
List<GeoPoint> northward(double startLat, double lon, int count) =>
    [for (var i = 0; i < count; i++) GeoPoint(startLat + i * kmLat, lon)];
