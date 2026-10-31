import 'route_catalog.dart';

/// 公式の停留所順の 1 停留所（名前と座標だけ）。
class OfficialStop {
  const OfficialStop({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;

  GeoPoint get point => GeoPoint(latitude, longitude);

  factory OfficialStop.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('stop is not an object');
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (name is! String || latitude is! num || longitude is! num) {
      throw const FormatException('stop needs name, latitude and longitude');
    }
    return OfficialStop(name: name, latitude: latitude.toDouble(), longitude: longitude.toDouble());
  }

  Map<String, dynamic> toJson() => {'name': name, 'latitude': latitude, 'longitude': longitude};
}

/// 系統と方向（[from] → [to]）ごとの停留所順 1 本。
class OfficialRoute {
  const OfficialRoute({required this.ref, this.from, this.to, required this.stops});

  final String ref;
  final String? from;
  final String? to;
  final List<OfficialStop> stops;

  factory OfficialRoute.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('route is not an object');
    final ref = json['ref'];
    final stops = json['stops'];
    if (ref is! String || ref.trim().isEmpty) throw const FormatException('route needs ref');
    if (stops is! List) throw FormatException('route $ref needs stops');
    return OfficialRoute(
      ref: ref,
      from: json['from'] as String?,
      to: json['to'] as String?,
      stops: [for (final s in stops) OfficialStop.fromJson(s)],
    );
  }

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'from': from,
        'to': to,
        'stops': [for (final s in stops) s.toJson()],
      };
}

/// 同梱または取得した停留所順のファイル（`assets/stop_order.json`）。
class OfficialStopOrderFile {
  const OfficialStopOrderFile({required this.updated, required this.routes});

  static const OfficialStopOrderFile empty = OfficialStopOrderFile(updated: '', routes: []);
  static final RegExp _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// `YYYY-MM-DD`。文字列の大小がそのまま日付の新旧。
  final String updated;
  final List<OfficialRoute> routes;

  /// 形が違えば [FormatException]。
  factory OfficialStopOrderFile.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('not a JSON object');
    final updated = json['updated'];
    final routes = json['routes'];
    if (updated is! String || !_date.hasMatch(updated)) throw const FormatException('updated must be YYYY-MM-DD');
    if (routes is! List) throw const FormatException('routes is not an array');
    return OfficialStopOrderFile(updated: updated, routes: [for (final r in routes) OfficialRoute.fromJson(r)]);
  }

  Map<String, dynamic> toJson() => {
        'updated': updated,
        'routes': [for (final r in routes) r.toJson()],
      };

  bool isNewerThan(OfficialStopOrderFile other) => updated.compareTo(other.updated) > 0;
}
