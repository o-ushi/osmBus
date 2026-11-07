import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';
import '../models/route_catalog.dart';
import 'app_settings.dart';

/// 登録済みの場所（Swift の `SavedPlace`）。[label] は「自宅」など、[placeName] は元の地名。
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.placeName,
    required this.point,
    this.subtitle,
    this.updatedAt,
  });

  factory SavedPlace.from(Destination destination, {required String label}) => SavedPlace(
        id: newId(),
        label: label,
        placeName: destination.name,
        subtitle: destination.subtitle,
        point: destination.point,
        updatedAt: DateTime.now().toUtc(),
      );

  final String id;
  final String label;
  final String placeName;
  final String? subtitle;
  final GeoPoint point;

  /// 最後に追加・編集した時刻。同期でどちらを残すかに使う。古いデータには無い。
  final DateTime? updatedAt;

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32).toRadixString(16)}';

  /// 2 行目に出す説明。
  String get detailLine {
    if (placeName == label) return subtitle ?? placeName;
    if (subtitle != null && subtitle!.isNotEmpty) return '$placeName · $subtitle';
    return placeName;
  }

  Destination toDestination() => Destination(
        name: label,
        subtitle: detailLine == label ? subtitle : detailLine,
        point: point,
      );

  SavedPlace copyWith({String? label, String? placeName, String? subtitle, GeoPoint? point, DateTime? updatedAt}) =>
      SavedPlace(
        id: id,
        label: label ?? this.label,
        placeName: placeName ?? this.placeName,
        subtitle: subtitle ?? this.subtitle,
        point: point ?? this.point,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'placeName': placeName,
        if (subtitle != null) 'subtitle': subtitle,
        'latitude': point.latitude,
        'longitude': point.longitude,
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  static SavedPlace fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        label: json['label'] as String,
        placeName: json['placeName'] as String,
        subtitle: json['subtitle'] as String?,
        point: GeoPoint((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
        updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

/// 目的地の履歴 1 件。
class HistoryEntry {
  const HistoryEntry({required this.destination, required this.setAt});

  final Destination destination;
  final DateTime setAt;

  Map<String, dynamic> toJson() => {'destination': destination.toJson(), 'setAt': setAt.toUtc().toIso8601String()};

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
        destination: Destination.fromJson(json['destination'] as Map<String, dynamic>),
        setAt: DateTime.parse(json['setAt'] as String),
      );
}

/// 1 路線分の、ユーザーが直した停留所。新しい形の配列か、これまでの ID 配列。
class RouteEdit {
  const RouteEdit({required this.relationId, required this.updatedAt, required this.stops});

  final int relationId;
  final DateTime updatedAt;
  final List<Object?> stops;

  Map<String, dynamic> toJson() => {
        'relationId': relationId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'stops': stops,
      };

  static RouteEdit fromJson(Map<String, dynamic> json) {
    final id = json['relationId'];
    final at = json['updatedAt'];
    final stops = json['stops'];
    if (id is! num || at is! String || stops is! List) {
      throw const FormatException('invalid route edit');
    }
    return RouteEdit(
      relationId: id.toInt(),
      updatedAt: DateTime.parse(at).toUtc(),
      stops: List<Object?>.from(stops),
    );
  }
}

/// iCloud とバックアップでやり取りする、登録済みの場所、目的地の履歴、直した停留所、設定。
/// [deletedPlaces]、[historyClearedAt]、[forgottenRouteEdits] は、消したものが他の端末から戻ってこないための印。
/// [settings] が null のファイルは、設定を持っていない古いバックアップなので、手元の設定を残す。
class PersonalData {
  const PersonalData({
    this.places = const [],
    this.history = const [],
    this.deletedPlaces = const {},
    this.historyClearedAt,
    this.routeEdits = const [],
    this.forgottenRouteEdits = const {},
    this.settings,
  });

  static const int schemaVersion = 1;

  /// これより古い削除の印は捨てる（溜まり続けないように）。
  static const Duration tombstoneLifetime = Duration(days: 180);

  final List<SavedPlace> places;
  final List<HistoryEntry> history;

  /// 消した場所の id と消した時刻。
  final Map<String, DateTime> deletedPlaces;

  /// 履歴を消した時刻。これ以前の履歴は戻さない。
  final DateTime? historyClearedAt;

  /// 直した停留所。同じ relationId は [updatedAt] が新しい方を残す。
  final List<RouteEdit> routeEdits;

  /// 「OSM の並びに戻す」で消した relationId と、消した時刻。
  final Map<int, DateTime> forgottenRouteEdits;

  /// 変えた設定。同じキーは [SyncedSetting.updatedAt] が新しい方を残す。null は「ファイルに無い」。
  final List<SyncedSetting>? settings;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'places': [for (final p in places) p.toJson()],
        'history': [for (final e in history) e.toJson()],
        'deletedPlaces': {for (final e in deletedPlaces.entries) e.key: e.value.toUtc().toIso8601String()},
        if (historyClearedAt != null) 'historyClearedAt': historyClearedAt!.toUtc().toIso8601String(),
        'routeEdits': [for (final e in routeEdits) e.toJson()],
        'forgottenRouteEdits': {
          for (final e in forgottenRouteEdits.entries) '${e.key}': e.value.toUtc().toIso8601String(),
        },
        if (settings != null) 'settings': [for (final s in settings!) s.toJson()],
      };

  /// 形が違えば [FormatException]。
  factory PersonalData.fromJson(Object? decoded) {
    if (decoded is! Map) throw const FormatException('personal data is not a JSON object');
    final version = decoded['schemaVersion'];
    if (version != null && version != schemaVersion) {
      throw FormatException('unsupported personal schemaVersion: $version');
    }
    try {
      final deleted = decoded['deletedPlaces'] as Map? ?? const {};
      final cleared = decoded['historyClearedAt'] as String?;
      final forgotten = decoded['forgottenRouteEdits'] as Map? ?? const {};
      final hasSettings = decoded.containsKey('settings');
      return PersonalData(
        places: [
          for (final p in decoded['places'] as List? ?? const [])
            SavedPlace.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        history: [
          for (final e in decoded['history'] as List? ?? const [])
            HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        deletedPlaces: {
          for (final e in deleted.entries) e.key as String: DateTime.parse(e.value as String).toUtc(),
        },
        historyClearedAt: cleared == null ? null : DateTime.parse(cleared).toUtc(),
        routeEdits: [
          for (final e in decoded['routeEdits'] as List? ?? const [])
            RouteEdit.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        forgottenRouteEdits: {
          for (final e in forgotten.entries) int.parse(e.key as String): DateTime.parse(e.value as String).toUtc(),
        },
        settings: hasSettings
            ? [
                for (final e in decoded['settings'] as List)
                  SyncedSetting.fromJson(Map<String, dynamic>.from(e as Map)),
              ]
            : null,
      );
    } catch (e) {
      throw e is FormatException ? e : FormatException('invalid personal data: $e');
    }
  }

  /// 和集合。同じ id の場所は新しい方、消した印より古い場所は落とす。
  /// 履歴は新しい順に並べ、同じ地点は新しい 1 件にまとめる。件数の上限はかけない。
  static PersonalData merge(PersonalData local, PersonalData remote, {required DateTime now}) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final deleted = <String, DateTime>{...local.deletedPlaces};
    remote.deletedPlaces.forEach((id, at) {
      final mine = deleted[id];
      if (mine == null || at.isAfter(mine)) deleted[id] = at;
    });
    deleted.removeWhere((_, at) => now.difference(at) > tombstoneLifetime);

    // 手元の並びを保ち、相手にしか無いものを後ろへ足す。
    final byId = <String, SavedPlace>{for (final p in local.places) p.id: p};
    for (final theirs in remote.places) {
      final mine = byId[theirs.id];
      if (mine == null || (theirs.updatedAt ?? epoch).isAfter(mine.updatedAt ?? epoch)) byId[theirs.id] = theirs;
    }
    final places = [
      for (final p in byId.values)
        if (deleted[p.id] == null || (p.updatedAt ?? epoch).isAfter(deleted[p.id]!)) p,
    ];

    final a = local.historyClearedAt;
    final b = remote.historyClearedAt;
    final cleared = a == null ? b : (b == null || a.isAfter(b) ? a : b);
    final entries = [
      for (final e in [...local.history, ...remote.history])
        if (cleared == null || e.setAt.isAfter(cleared)) e,
    ]..sort((x, y) => y.setAt.compareTo(x.setAt));
    final history = <HistoryEntry>[];
    for (final e in entries) {
      if (!history.any((kept) => kept.destination.samePlace(e.destination))) history.add(e);
    }

    final forgottenRoutes = <int, DateTime>{...local.forgottenRouteEdits};
    remote.forgottenRouteEdits.forEach((id, at) {
      final mine = forgottenRoutes[id];
      if (mine == null || at.isAfter(mine)) forgottenRoutes[id] = at;
    });
    forgottenRoutes.removeWhere((_, at) => now.difference(at) > tombstoneLifetime);

    final byRoute = <int, RouteEdit>{for (final e in local.routeEdits) e.relationId: e};
    for (final theirs in remote.routeEdits) {
      final mine = byRoute[theirs.relationId];
      if (mine == null || theirs.updatedAt.isAfter(mine.updatedAt)) byRoute[theirs.relationId] = theirs;
    }
    final routeEdits = [
      for (final e in byRoute.values)
        if (forgottenRoutes[e.relationId] == null || e.updatedAt.isAfter(forgottenRoutes[e.relationId]!)) e,
    ];

    return PersonalData(
      places: places,
      history: history,
      deletedPlaces: deleted,
      historyClearedAt: cleared,
      routeEdits: routeEdits,
      forgottenRouteEdits: forgottenRoutes,
      settings: mergeSettings(local.settings, remote.settings),
    );
  }

  /// 同じキーは新しい方。どちらかが設定を持っていなければ、持っている方を残す。
  static List<SyncedSetting>? mergeSettings(List<SyncedSetting>? local, List<SyncedSetting>? remote) {
    if (local == null) return remote;
    if (remote == null) return local;
    final byKey = <String, SyncedSetting>{for (final s in local) s.key: s};
    for (final theirs in remote) {
      final mine = byKey[theirs.key];
      if (mine == null || theirs.updatedAt.isAfter(mine.updatedAt)) byKey[theirs.key] = theirs;
    }
    return byKey.values.toList();
  }

  /// バックアップの置き換え。ファイルにあるキーは時刻に関わらずファイルを使い、ファイルに無いキーは手元を残す。
  static List<SyncedSetting>? overlaySettings(List<SyncedSetting>? local, List<SyncedSetting>? file) {
    if (file == null) return local;
    final byKey = <String, SyncedSetting>{for (final s in local ?? const []) s.key: s};
    for (final theirs in file) {
      byKey[theirs.key] = theirs;
    }
    return byKey.values.toList();
  }
}

/// 登録済みの場所と目的地の履歴。件数の上限は無い。
class PlacesStore extends ChangeNotifier {
  PlacesStore({required this.prefs});

  final SharedPreferences prefs;

  static const _placesKey = 'savedPlaces.list';
  static const _historyKey = 'destination.history';
  static const _deletedKey = 'savedPlaces.deleted';
  static const _historyClearedKey = 'destination.history.clearedAt';

  final StreamController<void> _localChanges = StreamController<void>.broadcast();

  /// 端末で追加・編集・削除したとき（同期やバックアップの反映では流さない）。
  Stream<void> get localChanges => _localChanges.stream;

  List<T> _read<T>(String key, T Function(Map<String, dynamic>) decode) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final decoded = <T>[];
      final seen = <String>{};
      for (final item in jsonDecode(raw) as List) {
        final value = decode(item as Map<String, dynamic>);
        final id = item['id'];
        if (id is String && !seen.add(id)) continue;
        decoded.add(value);
      }
      return decoded;
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(String key, List<Object> items, {bool local = true}) async {
    await prefs.setString(key, jsonEncode(items));
    notifyListeners();
    if (local) _localChanges.add(null);
  }

  List<SavedPlace> get places => _read(_placesKey, SavedPlace.fromJson);
  List<HistoryEntry> get history => _read(_historyKey, HistoryEntry.fromJson);

  Map<String, DateTime> get _deletedPlaces {
    try {
      final raw = jsonDecode(prefs.getString(_deletedKey) ?? '{}') as Map;
      return {for (final e in raw.entries) e.key as String: DateTime.parse(e.value as String).toUtc()};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeDeleted(Map<String, DateTime> deleted) =>
      prefs.setString(_deletedKey, jsonEncode({for (final e in deleted.entries) e.key: e.value.toIso8601String()}));

  DateTime? get _historyClearedAt => DateTime.tryParse(prefs.getString(_historyClearedKey) ?? '')?.toUtc();

  /// 同期とバックアップに渡す中身。
  PersonalData get data => PersonalData(
        places: places,
        history: history,
        deletedPlaces: _deletedPlaces,
        historyClearedAt: _historyClearedAt,
      );

  /// 同期・統合の結果を入れる。
  Future<void> apply(PersonalData data) async {
    await _writeDeleted(data.deletedPlaces);
    final cleared = data.historyClearedAt;
    if (cleared != null) await prefs.setString(_historyClearedKey, cleared.toUtc().toIso8601String());
    await _write(_placesKey, data.places, local: false);
    await _write(_historyKey, data.history, local: false);
  }

  Future<void> addPlace(SavedPlace place) async {
    await _write(_placesKey, [...places, place]);
  }

  Future<void> updatePlace(SavedPlace place) async {
    final edited = place.copyWith(updatedAt: DateTime.now().toUtc());
    await _write(_placesKey, [for (final p in places) p.id == place.id ? edited : p]);
  }

  Future<void> deletePlace(String id) async {
    await _writeDeleted({..._deletedPlaces, id: DateTime.now().toUtc()});
    await _write(_placesKey, [for (final p in places) if (p.id != id) p]);
  }

  /// 目的地を設定するたびに先頭へ足す。同じ地点は 1 件にまとめる。
  Future<void> addHistory(Destination destination, {DateTime? now}) async {
    final entries = [
      HistoryEntry(destination: destination, setAt: now ?? DateTime.now()),
      for (final e in history)
        if (!e.destination.samePlace(destination)) e,
    ];
    await _write(_historyKey, entries);
  }

  Future<void> clearHistory() async {
    await prefs.setString(_historyClearedKey, DateTime.now().toUtc().toIso8601String());
    await prefs.remove(_historyKey);
    notifyListeners();
    _localChanges.add(null);
  }

  /// 端末の中だけ消す（路線データと同じく iCloud 側は残す）。
  Future<void> clearAll() async {
    await prefs.remove(_placesKey);
    await prefs.remove(_historyKey);
    await prefs.remove(_deletedKey);
    await prefs.remove(_historyClearedKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _localChanges.close();
    super.dispose();
  }
}
