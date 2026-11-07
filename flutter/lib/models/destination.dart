import 'route_catalog.dart';

/// 目的地・出発地・登録地の地点（Swift の `Destination`）。
class Destination {
  const Destination({required this.name, required this.point, this.subtitle});

  final String name;
  final GeoPoint point;
  final String? subtitle;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (subtitle != null) 'subtitle': subtitle,
        'latitude': point.latitude,
        'longitude': point.longitude,
      };

  static Destination fromJson(Map<String, dynamic> json) => Destination(
        name: json['name'] as String,
        subtitle: json['subtitle'] as String?,
        point: GeoPoint((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
      );

  /// 同じ地点か（Swift と同じく緯度経度の差 0.00001 度未満）。
  bool samePlace(Destination other) => samePoint(point, other.point);

  static bool samePoint(GeoPoint a, GeoPoint b) =>
      (a.latitude - b.latitude).abs() < 0.00001 && (a.longitude - b.longitude).abs() < 0.00001;
}
