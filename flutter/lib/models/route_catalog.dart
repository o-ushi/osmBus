import 'dart:math' as math;

/// 緯度経度。JSON では `{latitude, longitude}`。
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

class RouteStop {
  const RouteStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  GeoPoint get point => GeoPoint(latitude, longitude);

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Stop',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'latitude': latitude, 'longitude': longitude};
}

/// Swift の `BusRouteCatalogStore.Record` の上位互換。
class RouteRecord {
  const RouteRecord({
    required this.relationId,
    required this.ref,
    required this.name,
    this.from,
    this.to,
    this.osmTimestamp,
    this.stops = const [],
    this.polylineSegments = const [],
    this.hasGeometry = false,
    this.updatedAt,
    this.anchorLatitude,
    this.anchorLongitude,
  });

  final int relationId;
  final String ref;
  final String name;
  final String? from;
  final String? to;
  final String? osmTimestamp;
  final List<RouteStop> stops;
  final List<List<GeoPoint>> polylineSegments;
  final bool hasGeometry;
  final DateTime? updatedAt;
  final double? anchorLatitude;
  final double? anchorLongitude;

  GeoPoint? get anchor => anchorLatitude != null && anchorLongitude != null
      ? GeoPoint(anchorLatitude!, anchorLongitude!)
      : null;

  String? get directionText {
    if (from != null && to != null && from!.isNotEmpty && to!.isNotEmpty) {
      return '$from → $to';
    }
    return name != ref ? name : null;
  }

  static const _unset = Object();

  RouteRecord copyWith({
    String? ref,
    String? name,
    Object? from = _unset,
    Object? to = _unset,
    Object? osmTimestamp = _unset,
    List<RouteStop>? stops,
    List<List<GeoPoint>>? polylineSegments,
    bool? hasGeometry,
    Object? updatedAt = _unset,
    Object? anchorLatitude = _unset,
    Object? anchorLongitude = _unset,
  }) {
    return RouteRecord(
      relationId: relationId,
      ref: ref ?? this.ref,
      name: name ?? this.name,
      from: identical(from, _unset) ? this.from : from as String?,
      to: identical(to, _unset) ? this.to : to as String?,
      osmTimestamp:
          identical(osmTimestamp, _unset) ? this.osmTimestamp : osmTimestamp as String?,
      stops: stops ?? this.stops,
      polylineSegments: polylineSegments ?? this.polylineSegments,
      hasGeometry: hasGeometry ?? this.hasGeometry,
      updatedAt: identical(updatedAt, _unset) ? this.updatedAt : updatedAt as DateTime?,
      anchorLatitude:
          identical(anchorLatitude, _unset) ? this.anchorLatitude : anchorLatitude as double?,
      anchorLongitude: identical(anchorLongitude, _unset)
          ? this.anchorLongitude
          : anchorLongitude as double?,
    );
  }

  /// 必須フィールドが欠けていれば [FormatException]。
  factory RouteRecord.fromJson(Map<String, dynamic> json) {
    final relationId = json['relationId'];
    final ref = json['ref'];
    if (relationId is! num) throw const FormatException('relationId is missing');
    if (ref is! String) throw FormatException('ref is missing ($relationId)');
    final stops = (json['stops'] as List? ?? const [])
        .map((s) => RouteStop.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    final segments = (json['polylineSegments'] as List? ?? const [])
        .map((seg) => (seg as List)
            .map((p) => GeoPoint.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList())
        .toList();
    return RouteRecord(
      relationId: relationId.toInt(),
      ref: ref,
      name: json['name'] as String? ?? ref,
      from: json['from'] as String?,
      to: json['to'] as String?,
      osmTimestamp: json['osmTimestamp'] as String?,
      stops: stops,
      polylineSegments: segments,
      hasGeometry: json['hasGeometry'] as bool? ?? false,
      updatedAt: CatalogDates.decode(json['updatedAt']),
      anchorLatitude: (json['anchorLatitude'] as num?)?.toDouble(),
      anchorLongitude: (json['anchorLongitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'relationId': relationId,
        'ref': ref,
        'name': name,
        'from': from,
        'to': to,
        'osmTimestamp': osmTimestamp,
        'stops': stops.map((s) => s.toJson()).toList(),
        'polylineSegments':
            polylineSegments.map((seg) => seg.map((p) => p.toJson()).toList()).toList(),
        'hasGeometry': hasGeometry,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
        'anchorLatitude': anchorLatitude,
        'anchorLongitude': anchorLongitude,
      };
}

abstract final class CatalogDates {
  /// Swift `JSONEncoder` 既定の基準日（2001-01-01 UTC）。
  static final DateTime swiftReferenceDate = DateTime.utc(2001);

  static DateTime? decode(Object? value) {
    if (value is num) {
      return swiftReferenceDate.add(Duration(microseconds: (value * 1000000).round()));
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

/// 端末内の正本ファイルのエンベロープ。
class CatalogSnapshot {
  const CatalogSnapshot({this.syncedAt, this.routes = const []});

  static const int schemaVersion = 1;
  static const CatalogSnapshot empty = CatalogSnapshot();

  final DateTime? syncedAt;
  final List<RouteRecord> routes;

  int get geometryCount => routes.where((r) => r.hasGeometry).length;

  /// 読み込み。Swift 版のファイル（schemaVersion なし、数値日付）も読む。
  /// [strict] のときは検証に失敗したレコードがあれば [FormatException]。
  /// そうでなければそのレコードだけ読み飛ばす。
  factory CatalogSnapshot.fromJson(Object? decoded, {bool strict = false}) {
    if (decoded is! Map) throw const FormatException('not a JSON object');
    final version = decoded['schemaVersion'];
    if (version != null && version != schemaVersion) {
      throw FormatException('unsupported schemaVersion: $version');
    }
    final rawRoutes = decoded['routes'];
    if (rawRoutes is! List) throw const FormatException('routes is not an array');
    final routes = <RouteRecord>[];
    for (final raw in rawRoutes) {
      try {
        if (raw is! Map) throw const FormatException('route is not an object');
        final record = RouteRecord.fromJson(Map<String, dynamic>.from(raw));
        if (record.ref.trim().isEmpty) continue;
        routes.add(record);
      } catch (e) {
        if (strict) {
          throw e is FormatException ? e : FormatException('invalid route: $e');
        }
      }
    }
    return CatalogSnapshot(syncedAt: CatalogDates.decode(decoded['syncedAt']), routes: routes);
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'dateEncoding': 'iso8601',
        'syncedAt': syncedAt?.toUtc().toIso8601String(),
        'routes': routes.where((r) => r.ref.trim().isNotEmpty).map((r) => r.toJson()).toList(),
      };

  CatalogSnapshot copyWith({DateTime? syncedAt, List<RouteRecord>? routes}) =>
      CatalogSnapshot(syncedAt: syncedAt ?? this.syncedAt, routes: routes ?? this.routes);
}

/// Overpass の見出し（§4.1）。
class CatalogTag {
  const CatalogTag({
    required this.id,
    required this.ref,
    required this.name,
    this.from,
    this.to,
    this.timestamp,
  });

  final int id;
  final String ref;
  final String name;
  final String? from;
  final String? to;
  final String? timestamp;
}

/// Overpass の形状（§4.2）。
class RouteDetail {
  const RouteDetail({
    required this.relationId,
    required this.stops,
    required this.polylineSegments,
  });

  final int relationId;
  final List<RouteStop> stops;
  final List<List<GeoPoint>> polylineSegments;
}

/// カタログの純粋な変換。ストアとテストの両方から使う。
abstract final class CatalogOps {
  static const double dropRadiusMeters = 80000;

  /// §4.3 見出しの取り込み。
  static CatalogSnapshot applyTags(
    CatalogSnapshot snapshot,
    List<CatalogTag> tags, {
    required GeoPoint origin,
    required bool dropMissing,
    required DateTime now,
    required double Function(GeoPoint, GeoPoint) distance,
  }) {
    final byId = {for (final r in snapshot.routes) r.relationId: r};
    final freshIds = <int>{};

    for (final tag in tags) {
      if (tag.ref.trim().isEmpty) continue;
      freshIds.add(tag.id);
      final existing = byId[tag.id];
      if (existing == null) {
        byId[tag.id] = RouteRecord(
          relationId: tag.id,
          ref: tag.ref,
          name: tag.name,
          from: tag.from,
          to: tag.to,
          osmTimestamp: tag.timestamp,
          updatedAt: now,
          anchorLatitude: origin.latitude,
          anchorLongitude: origin.longitude,
        );
        continue;
      }
      final timestampChanged = existing.osmTimestamp != tag.timestamp;
      final textChanged = existing.ref != tag.ref ||
          existing.name != tag.name ||
          existing.from != tag.from ||
          existing.to != tag.to;
      var updated = existing.copyWith(ref: tag.ref, name: tag.name, from: tag.from, to: tag.to);
      if (timestampChanged || !existing.hasGeometry) {
        updated = updated.copyWith(
          osmTimestamp: tag.timestamp,
          hasGeometry: false,
          stops: const [],
          polylineSegments: const [],
        );
      }
      if (timestampChanged || textChanged) {
        updated = updated.copyWith(updatedAt: now);
      }
      byId[tag.id] = updated;
    }

    if (dropMissing) {
      byId.removeWhere((id, record) {
        if (freshIds.contains(id)) return false;
        final anchor = record.anchor;
        if (anchor == null) return false;
        return distance(anchor, origin) <= dropRadiusMeters;
      });
    }

    return CatalogSnapshot(syncedAt: now, routes: byId.values.toList());
  }

  /// 形状を付ける。アンカーが空なら中央の停留所、停留所が無ければ [downloadOrigin]。
  static RouteRecord attachGeometry(
    RouteRecord record,
    RouteDetail detail, {
    required DateTime now,
    required GeoPoint downloadOrigin,
  }) {
    var updated = record.copyWith(
      stops: detail.stops,
      polylineSegments: detail.polylineSegments,
      hasGeometry: true,
      updatedAt: now,
    );
    if (updated.anchor == null) {
      final anchor = detail.stops.isNotEmpty
          ? detail.stops[detail.stops.length ~/ 2].point
          : downloadOrigin;
      updated = updated.copyWith(
        anchorLatitude: anchor.latitude,
        anchorLongitude: anchor.longitude,
      );
    }
    return updated;
  }

  /// §5.4 マージ。和集合。両方にある id は新しい方。
  static CatalogSnapshot merge(
    CatalogSnapshot local,
    CatalogSnapshot remote, {
    required DateTime now,
  }) {
    final byId = <int, RouteRecord>{for (final r in local.routes) r.relationId: r};
    for (final theirs in remote.routes) {
      final mine = byId[theirs.relationId];
      byId[theirs.relationId] = mine == null ? theirs : pickNewer(mine, theirs);
    }
    final routes = byId.values.toList()..sort((a, b) => a.relationId.compareTo(b.relationId));
    return CatalogSnapshot(syncedAt: now, routes: routes);
  }

  /// [mine] が手元、[theirs] が相手。決まらなければ手元。
  static RouteRecord pickNewer(RouteRecord mine, RouteRecord theirs) {
    final a = mine.updatedAt;
    final b = theirs.updatedAt;
    if (a != null && b != null && a != b) return b.isAfter(a) ? theirs : mine;
    if (mine.hasGeometry != theirs.hasGeometry) return theirs.hasGeometry ? theirs : mine;
    final ta = mine.osmTimestamp ?? '';
    final tb = theirs.osmTimestamp ?? '';
    final order = ta.compareTo(tb);
    if (order != 0) return order < 0 ? theirs : mine;
    return mine;
  }

  /// 保管庫へ形状付きの路線を足す。保管庫からは消さない。
  /// 変わらなければ [archive] をそのまま返す（書き込みを省くため）。
  static CatalogSnapshot archive(CatalogSnapshot archive, CatalogSnapshot snapshot, {required DateTime now}) {
    final byId = <int, RouteRecord>{for (final r in archive.routes) r.relationId: r};
    var changed = false;
    for (final r in snapshot.routes) {
      if (!r.hasGeometry) continue;
      final kept = byId[r.relationId];
      if (kept != null && _sameArchived(kept, r)) continue;
      if (kept != null && (kept.osmTimestamp ?? '').compareTo(r.osmTimestamp ?? '') > 0) continue;
      byId[r.relationId] = r;
      changed = true;
    }
    if (!changed) return archive;
    final routes = byId.values.toList()..sort((a, b) => a.relationId.compareTo(b.relationId));
    return CatalogSnapshot(syncedAt: now, routes: routes);
  }

  static bool _sameArchived(RouteRecord a, RouteRecord b) =>
      a.osmTimestamp == b.osmTimestamp &&
      a.updatedAt == b.updatedAt &&
      a.ref == b.ref &&
      a.stops.length == b.stops.length &&
      a.polylineSegments.length == b.polylineSegments.length;

  /// 形状のない路線に、OSM の版が同じ保管庫の形状を戻す。戻した路線は再取得しない。
  static CatalogSnapshot restoreGeometry(CatalogSnapshot snapshot, CatalogSnapshot archive) {
    if (archive.routes.isEmpty) return snapshot;
    final byId = {for (final r in archive.routes) r.relationId: r};
    var changed = false;
    final routes = <RouteRecord>[];
    for (final r in snapshot.routes) {
      final kept = byId[r.relationId];
      if (!r.hasGeometry && kept != null && kept.hasGeometry && kept.osmTimestamp == r.osmTimestamp) {
        routes.add(kept.copyWith(ref: r.ref, name: r.name, from: r.from, to: r.to));
        changed = true;
      } else {
        routes.add(r);
      }
    }
    return changed ? snapshot.copyWith(routes: routes) : snapshot;
  }

  /// 400 点を超える way を間引く（Swift の `decimateCoordinates`）。
  static List<GeoPoint> decimate(List<GeoPoint> points, {int maxPoints = 400}) {
    if (points.length <= maxPoints) return points;
    final last = points.length - 1;
    return List.generate(maxPoints, (i) => points[math.min(last, (i * last) ~/ (maxPoints - 1))]);
  }
}
