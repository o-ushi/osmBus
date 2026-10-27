import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/route_catalog.dart';
import 'app_log.dart';

enum OverpassErrorKind { network, parse, serverTimeout, serverProcessing, serverHttp }

class OverpassException implements Exception {
  const OverpassException(this.kind, [this.detail]);

  final OverpassErrorKind kind;
  final String? detail;

  @override
  String toString() => 'OverpassException($kind${detail == null ? '' : ': $detail'})';
}

/// Swift の `OverpassAPIService` と同じエンドポイント順・クエリ・パース。
class OverpassApi {
  OverpassApi({http.Client? client}) : _client = client ?? http.Client();

  static final List<Uri> endpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
    Uri.parse('https://maps.mail.ru/osm/tools/overpass/api/interpreter'),
  ];

  static const String userAgent = 'osmBus Flutter/1.0';
  static const int catalogRadiusMeters = 80000;

  final http.Client _client;

  /// §4.1 見出し。
  Future<List<CatalogTag>> fetchCatalog(GeoPoint near) async {
    final query = '[out:json][timeout:90];\n'
        'relation["type"="route"]["route"~"bus|trolleybus"]'
        '(around:$catalogRadiusMeters,${near.latitude},${near.longitude});\n'
        'out tags meta;';
    final body = await _post(query, const Duration(seconds: 100));
    return parseCatalogTags(body);
  }

  /// §4.2 形状。
  Future<List<RouteDetail>> fetchDetails(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final query = '[out:json][timeout:90];\n'
        'relation(id:${ids.join(',')});\n'
        'out body;\n'
        '>;\n'
        'out body;';
    final body = await _post(query, const Duration(seconds: 100));
    return parseDetails(body, ids);
  }

  Future<String> _post(String query, Duration timeout) async {
    Object lastError = const OverpassException(OverpassErrorKind.network, 'timeout');
    for (final endpoint in endpoints) {
      try {
        final response = await _client
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': userAgent,
              },
              body: 'data=${Uri.encodeQueryComponent(query)}',
            )
            .timeout(timeout);
        if (response.statusCode < 200 || response.statusCode > 299) {
          throw OverpassException(OverpassErrorKind.serverHttp, 'HTTP ${response.statusCode}');
        }
        final text = utf8.decode(response.bodyBytes);
        _checkRemark(text);
        return text;
      } on OverpassException catch (e) {
        if (e.kind == OverpassErrorKind.parse) rethrow;
        AppLog.w('overpass', '${endpoint.host} $e');
        lastError = e;
      } catch (e) {
        AppLog.w('overpass', '${endpoint.host} $e');
        lastError = OverpassException(OverpassErrorKind.network, '$e');
      }
    }
    throw lastError;
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    throw const OverpassException(OverpassErrorKind.parse);
  }

  static void _checkRemark(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return;
    }
    if (json is! Map) return;
    final remark = json['remark'];
    if (remark is! String || remark.isEmpty) return;
    final lower = remark.toLowerCase();
    if (lower.contains('timeout') || lower.contains('out of time') || lower.contains('timed out')) {
      throw const OverpassException(OverpassErrorKind.serverTimeout);
    }
    if (lower.contains('runtime error') || lower.contains('error')) {
      throw const OverpassException(OverpassErrorKind.serverProcessing);
    }
  }

  static List<Map<String, dynamic>> _elements(Map<String, dynamic> json) {
    final elements = json['elements'];
    if (elements is! List) throw const OverpassException(OverpassErrorKind.parse);
    return elements.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static Map<String, String> _tags(Map<String, dynamic> element) {
    final tags = element['tags'];
    if (tags is! Map) return const {};
    return {
      for (final e in tags.entries)
        if (e.value is String) e.key as String: e.value as String,
    };
  }

  static List<CatalogTag> parseCatalogTags(String body) {
    final tags = <CatalogTag>[];
    for (final el in _elements(_decode(body))) {
      if (el['type'] != 'relation' || el['id'] is! num) continue;
      final t = _tags(el);
      final ref = t['ref']?.trim() ?? '';
      if (ref.isEmpty) continue;
      tags.add(CatalogTag(
        id: (el['id'] as num).toInt(),
        ref: ref,
        name: t['name'] ?? ref,
        from: t['from'],
        to: t['to'],
        timestamp: el['timestamp'] as String?,
      ));
    }
    return tags;
  }

  static const Set<String> _roadStopRoles = {
    'stop',
    'stop_entry_only',
    'stop_exit_only',
    'stop_entry',
    'stop_exit',
  };
  static const Set<String> _platformRoles = {
    'platform',
    'platform_entry_only',
    'platform_exit_only',
  };

  /// Swift の `parseDetails` と同じ並び。road-side の stop を優先し、無ければ platform。
  static List<RouteDetail> parseDetails(String body, List<int> ids) {
    final nodeCoords = <int, GeoPoint>{};
    final nodeNames = <int, String>{};
    final busStopNodes = <int>{};
    final wayNodes = <int, List<int>>{};
    final relations = <int, Map<String, dynamic>>{};

    for (final el in _elements(_decode(body))) {
      final id = el['id'];
      if (id is! num) continue;
      switch (el['type']) {
        case 'node':
          final lat = el['lat'];
          final lon = el['lon'];
          if (lat is num && lon is num) {
            nodeCoords[id.toInt()] = GeoPoint(lat.toDouble(), lon.toDouble());
          }
          final t = _tags(el);
          final name = t['name'] ?? t['name:en'] ?? t['name:vi'];
          if (name != null) nodeNames[id.toInt()] = name;
          if (t['highway'] == 'bus_stop') busStopNodes.add(id.toInt());
        case 'way':
          final nodes = el['nodes'];
          if (nodes is List) wayNodes[id.toInt()] = nodes.whereType<num>().map((n) => n.toInt()).toList();
        case 'relation':
          relations[id.toInt()] = el;
      }
    }

    final details = <RouteDetail>[];
    for (final id in ids) {
      final relation = relations[id];
      if (relation == null) continue;
      final detail = _detail(id, relation, nodeCoords, nodeNames, busStopNodes, wayNodes);
      if (detail != null) details.add(detail);
    }
    return details;
  }

  static RouteDetail? _detail(
    int relationId,
    Map<String, dynamic> relation,
    Map<int, GeoPoint> nodeCoords,
    Map<int, String> nodeNames,
    Set<int> busStopNodes,
    Map<int, List<int>> wayNodes,
  ) {
    final members = relation['members'];
    if (members is! List) return null;

    final wayIds = <int>[];
    final stopNodeIds = <int>[];
    final platformNodeIds = <int>[];
    for (final member in members.whereType<Map>()) {
      final type = member['type'];
      final ref = member['ref'];
      if (type is! String || ref is! num) continue;
      final role = member['role'] as String? ?? '';
      if (type == 'way') {
        wayIds.add(ref.toInt());
      } else if (type == 'node') {
        if (_roadStopRoles.contains(role)) {
          stopNodeIds.add(ref.toInt());
        } else if (_platformRoles.contains(role) ||
            (role.isEmpty && busStopNodes.contains(ref.toInt()))) {
          platformNodeIds.add(ref.toInt());
        }
      }
    }
    final finalStopIds = stopNodeIds.isEmpty ? platformNodeIds : stopNodeIds;

    final segments = <List<GeoPoint>>[];
    var waysInLastSegment = 0;
    for (final wayId in wayIds) {
      final nodes = wayNodes[wayId];
      if (nodes == null) continue;
      final coords = [for (final n in nodes) ?nodeCoords[n]];
      if (coords.length < 2) continue;
      waysInLastSegment =
          _appendWay(segments, CatalogOps.decimate(coords), waysInLastSegment);
    }

    final seen = <int>{};
    final stops = <RouteStop>[];
    for (final nodeId in finalStopIds) {
      final coord = nodeCoords[nodeId];
      if (!seen.add(nodeId) || coord == null) continue;
      stops.add(RouteStop(
        id: nodeId,
        name: nodeNames[nodeId] ?? 'Stop',
        latitude: coord.latitude,
        longitude: coord.longitude,
      ));
    }

    return RouteDetail(relationId: relationId, stops: stops, polylineSegments: segments);
  }

  /// way を順に座標列へつなぐ。向きが逆なら反転し、途切れたら別セグメントにする。
  /// 戻り値は最後のセグメントに入っている way の数。
  static int _appendWay(List<List<GeoPoint>> segments, List<GeoPoint> way, int waysInLast) {
    if (segments.isEmpty) {
      segments.add([...way]);
      return 1;
    }
    final current = segments.last;
    if (current.last == way.first) {
      current.addAll(way.skip(1));
      return waysInLast + 1;
    }
    if (current.last == way.last) {
      current.addAll(way.reversed.skip(1));
      return waysInLast + 1;
    }
    if (waysInLast == 1 && (current.first == way.first || current.first == way.last)) {
      // セグメント最初の way が逆向きに並んでいた場合。
      final reversed = current.reversed.toList();
      current
        ..clear()
        ..addAll(reversed)
        ..addAll(current.last == way.first ? way.skip(1) : way.reversed.skip(1));
      return 2;
    }
    segments.add([...way]);
    return 1;
  }
}
