import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';
import '../models/route_catalog.dart';

/// 登録済みの場所（Swift の `SavedPlace`）。[label] は「自宅」など、[placeName] は元の地名。
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.placeName,
    required this.point,
    this.subtitle,
  });

  factory SavedPlace.from(Destination destination, {required String label}) => SavedPlace(
        id: newId(),
        label: label,
        placeName: destination.name,
        subtitle: destination.subtitle,
        point: destination.point,
      );

  final String id;
  final String label;
  final String placeName;
  final String? subtitle;
  final GeoPoint point;

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

  SavedPlace copyWith({String? label, String? placeName, String? subtitle, GeoPoint? point}) => SavedPlace(
        id: id,
        label: label ?? this.label,
        placeName: placeName ?? this.placeName,
        subtitle: subtitle ?? this.subtitle,
        point: point ?? this.point,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'placeName': placeName,
        if (subtitle != null) 'subtitle': subtitle,
        'latitude': point.latitude,
        'longitude': point.longitude,
      };

  static SavedPlace fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        label: json['label'] as String,
        placeName: json['placeName'] as String,
        subtitle: json['subtitle'] as String?,
        point: GeoPoint((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
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

enum AppPlan { free, paid }

/// FREE / PREMIUM と、それに応じた件数上限（Swift の `PlanStore`）。
class PlanStore extends ChangeNotifier {
  PlanStore(this.prefs);

  final SharedPreferences prefs;

  static const int freeItemLimit = 3;
  static const _planKey = 'plan.current';

  AppPlan get plan => AppPlan.values.asNameMap()[prefs.getString(_planKey)] ?? AppPlan.free;
  bool get isPaid => plan == AppPlan.paid;

  /// null は無制限。
  int? get itemLimit => isPaid ? null : freeItemLimit;

  Future<void> setPlan(AppPlan plan) async {
    if (plan == this.plan) return;
    await prefs.setString(_planKey, plan.name);
    notifyListeners();
  }
}

/// 登録済みの場所と目的地の履歴。FREE は各 3 件まで（PREMIUM は無制限）。
class PlacesStore extends ChangeNotifier {
  PlacesStore({required this.prefs, required this.plan}) {
    plan.addListener(_onPlanChanged);
  }

  final SharedPreferences prefs;
  final PlanStore plan;

  static const _placesKey = 'savedPlaces.list';
  static const _historyKey = 'destination.history';

  List<T> _read<T>(String key, T Function(Map<String, dynamic>) decode) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return [for (final item in jsonDecode(raw) as List) decode(item as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(String key, List<Object> items) async {
    await prefs.setString(key, jsonEncode(items));
    notifyListeners();
  }

  List<SavedPlace> get places => _read(_placesKey, SavedPlace.fromJson);
  List<HistoryEntry> get history => _read(_historyKey, HistoryEntry.fromJson);

  bool get canAddPlace {
    final limit = plan.itemLimit;
    return limit == null || places.length < limit;
  }

  /// 上限に達していれば false（保存しない）。
  Future<bool> addPlace(SavedPlace place) async {
    if (!canAddPlace) return false;
    await _write(_placesKey, [...places, place]);
    return true;
  }

  Future<void> updatePlace(SavedPlace place) async {
    await _write(_placesKey, [for (final p in places) p.id == place.id ? place : p]);
  }

  Future<void> deletePlace(String id) async {
    await _write(_placesKey, [for (final p in places) if (p.id != id) p]);
  }

  /// 目的地を設定するたびに先頭へ足す。同じ地点は 1 件にまとめる。
  Future<void> addHistory(Destination destination, {DateTime? now}) async {
    final entries = [
      HistoryEntry(destination: destination, setAt: now ?? DateTime.now()),
      for (final e in history)
        if (!e.destination.samePlace(destination)) e,
    ];
    final limit = plan.itemLimit;
    await _write(_historyKey, limit == null ? entries : entries.take(limit).toList());
  }

  Future<void> clearHistory() async {
    await prefs.remove(_historyKey);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await prefs.remove(_placesKey);
    await prefs.remove(_historyKey);
    notifyListeners();
  }

  /// FREE に戻ったら上限まで切り詰める（Swift の `enforceLimitsForCurrentPlan`）。
  Future<void> _onPlanChanged() async {
    final limit = plan.itemLimit;
    if (limit == null) return;
    if (places.length > limit) await _write(_placesKey, places.take(limit).toList());
    if (history.length > limit) await _write(_historyKey, history.take(limit).toList());
  }

  @override
  void dispose() {
    plan.removeListener(_onPlanChanged);
    super.dispose();
  }
}
