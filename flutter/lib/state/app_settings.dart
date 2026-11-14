import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bus_matrix.dart';

/// 表示言語（Swift の `AppLanguage`）。null は端末の言語に従う。
enum AppLanguage {
  english('en', 'English', '🇺🇸'),
  japanese('ja', '日本語', '🇯🇵'),
  vietnamese('vi', 'Tiếng Việt', '🇻🇳');

  const AppLanguage(this.code, this.displayName, this.flag);

  final String code;
  final String displayName;
  final String flag;

  String get fullLabel => '$flag $displayName';

  static AppLanguage? fromCode(String? code) =>
      AppLanguage.values.where((l) => l.code == code).firstOrNull;
}

/// 判定後に数字キーを押したときの動き（Swift の `BusKeypadInputMode`）。
enum KeypadInputMode { clearBeforeNewInput, appendToExisting }

/// 振動の強さ。キーと到着アラートで共用。
enum FeedbackStrength { light, medium, heavy }

/// 到着アラートの鳴り方（Swift の `StopAlertMode`）。
enum StopAlertMode {
  alarm(defaultEnabled: false),
  alert(defaultEnabled: true),
  vibration(defaultEnabled: true);

  const StopAlertMode({required this.defaultEnabled});

  final bool defaultEnabled;
}

/// 距離アラートの 1 段（Swift の `DistanceAlertSlot`）。
class DistanceAlertSlot {
  const DistanceAlertSlot({
    required this.index,
    required this.enabled,
    required this.meters,
  });

  static const int count = 3;
  static const List<int> defaultMeters = [1000, 400, 100];
  static const List<int> presets = [
    50,
    100,
    150,
    200,
    300,
    400,
    500,
    750,
    1000,
    1500,
    2000,
  ];

  final int index;
  final bool enabled;
  final int meters;
}

/// 1 件の設定と、変えた時刻。同じキーは時刻が新しい方を残す。
class SyncedSetting {
  const SyncedSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  final String key;
  final Object? value;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static SyncedSetting fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final at = json['updatedAt'];
    if (key is! String ||
        key.isEmpty ||
        at is! String ||
        !json.containsKey('value')) {
      throw const FormatException('invalid setting');
    }
    final setting = SyncedSetting(
      key: key,
      value: json['value'],
      updatedAt: DateTime.parse(at).toUtc(),
    );
    if (!SettingsSync.valid(setting))
      throw FormatException('invalid setting $key');
    return setting;
  }
}

/// 設定のうち、iCloud とバックアップでやり取りするもの。
/// 値そのものはこれまでどおり各キーに置き、変えた時刻だけを別に覚える。
class SettingsSync {
  static const timesKey = 'settings.updatedAt';

  static const keys = <String>{
    'appLanguage',
    'keypad.inputMode',
    'keypad.hapticEnabled',
    'keypad.hapticStrength',
    'keypad.soundEnabled',
    'keypad.soundVolume',
    'alert.soundId',
    'alert.followsSystem',
    'alert.soundVolume',
    'alert.vibrationStrength',
    'alert.mode.alarm',
    'alert.mode.alert',
    'alert.mode.vibration',
    'alert.distance.0.enabled',
    'alert.distance.0.meters',
    'alert.distance.1.enabled',
    'alert.distance.1.meters',
    'alert.distance.2.enabled',
    'alert.distance.2.meters',
    'table.sortMode',
    'table.distanceMetric',
  };

  static const _bools = <String>{
    'keypad.hapticEnabled',
    'keypad.soundEnabled',
    'alert.followsSystem',
    'alert.mode.alarm',
    'alert.mode.alert',
    'alert.mode.vibration',
    'alert.distance.0.enabled',
    'alert.distance.1.enabled',
    'alert.distance.2.enabled',
  };

  static const _doubles = <String>{'keypad.soundVolume', 'alert.soundVolume'};

  static const _ints = <String>{
    'alert.distance.0.meters',
    'alert.distance.1.meters',
    'alert.distance.2.meters',
  };

  /// 知らないキーは将来の版のため通す。知っているキーは型が違えば落とす。
  static bool valid(SyncedSetting setting) {
    if (!keys.contains(setting.key)) return true;
    final value = setting.value;
    if (setting.key == 'appLanguage') {
      return value == null ||
          (value is String && AppLanguage.fromCode(value) != null);
    }
    if (setting.key == 'alert.soundId')
      return value is String && value.isNotEmpty;
    if (_bools.contains(setting.key)) return value is bool;
    if (_doubles.contains(setting.key)) return value is num;
    if (_ints.contains(setting.key)) return value is num && value > 0;
    final name = value is String ? value : null;
    final names = switch (setting.key) {
      'keypad.inputMode' => KeypadInputMode.values.map((e) => e.name),
      'keypad.hapticStrength' ||
      'alert.vibrationStrength' => FeedbackStrength.values.map((e) => e.name),
      'table.sortMode' => TableSortMode.values.map((e) => e.name),
      'table.distanceMetric' => DistanceMetric.values.map((e) => e.name),
      _ => const <String>[],
    };
    return name != null && names.contains(name);
  }

  static Map<String, DateTime> _readTimes(SharedPreferences prefs) {
    final raw = prefs.getString(timesKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in json.entries)
          e.key: DateTime.parse(e.value as String).toUtc(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeTimes(
    SharedPreferences prefs,
    Map<String, DateTime> times,
  ) async {
    if (times.isEmpty) {
      await prefs.remove(timesKey);
      return;
    }
    await prefs.setString(
      timesKey,
      jsonEncode({
        for (final e in times.entries) e.key: e.value.toUtc().toIso8601String(),
      }),
    );
  }

  /// ユーザーが変えたときに呼ぶ。同期の予約は呼び出し側。
  static Future<void> touch(SharedPreferences prefs, String key) async {
    final times = _readTimes(prefs);
    times[key] = DateTime.now().toUtc();
    await _writeTimes(prefs, times);
  }

  /// 一度でも変えた設定。時刻の無い古い変更には、いまの時刻を付けて残す。
  static List<SyncedSetting> collect(SharedPreferences prefs, {DateTime? now}) {
    final times = _readTimes(prefs);
    final clock = (now ?? DateTime.now()).toUtc();
    var dirty = false;
    final out = <SyncedSetting>[];
    for (final key in keys) {
      final present = prefs.containsKey(key);
      var at = times[key];
      if (!present && at == null) continue;
      if (at == null) {
        at = clock;
        times[key] = at;
        dirty = true;
      }
      out.add(
        SyncedSetting(
          key: key,
          value: present ? prefs.get(key) : null,
          updatedAt: at,
        ),
      );
    }
    if (dirty) unawaited(_writeTimes(prefs, times));
    return out;
  }

  /// [incoming] のうち、手元より新しいものだけを書く。ユーザー操作としては扱わない。
  /// [force] なら時刻に関わらず書く（バックアップの置き換え）。
  static Future<bool> apply(
    SharedPreferences prefs,
    List<SyncedSetting> incoming, {
    bool force = false,
  }) async {
    final times = _readTimes(prefs);
    var changed = false;
    for (final setting in incoming) {
      if (!keys.contains(setting.key) || !valid(setting)) continue;
      final mine = times[setting.key];
      if (!force && mine != null && !setting.updatedAt.isAfter(mine)) continue;
      await _writeValue(prefs, setting.key, setting.value);
      times[setting.key] = setting.updatedAt;
      changed = true;
    }
    if (changed) await _writeTimes(prefs, times);
    return changed;
  }

  static Future<void> _writeValue(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (_ints.contains(key) && value is num) {
      await prefs.setInt(key, value.round());
    } else if (value is num) {
      await prefs.setDouble(key, value.toDouble());
    }
  }
}

/// アプリ全体の設定。値は SharedPreferences に置く。
class AppSettings extends ChangeNotifier {
  AppSettings(this.prefs);

  final SharedPreferences prefs;

  /// ユーザーが設定を変えたとき。同期の反映では呼ばない。
  void Function()? onLocalChange;

  static const _languageKey = 'appLanguage';
  static const _showStartupScreenKey = 'showStartupScreen';
  static const _keypadModeKey = 'keypad.inputMode';
  static const _hapticEnabledKey = 'keypad.hapticEnabled';
  static const _hapticStrengthKey = 'keypad.hapticStrength';
  static const _clickEnabledKey = 'keypad.soundEnabled';
  static const _clickVolumeKey = 'keypad.soundVolume';
  static const _alertSoundKey = 'alert.soundId';
  static const _alertFollowsSystemKey = 'alert.followsSystem';
  static const _alertVolumeKey = 'alert.soundVolume';
  static const _alertVibrationStrengthKey = 'alert.vibrationStrength';
  static String _alertModeKey(StopAlertMode mode) => 'alert.mode.${mode.name}';
  static String _slotEnabledKey(int index) => 'alert.distance.$index.enabled';
  static String _slotMetersKey(int index) => 'alert.distance.$index.meters';

  static const double defaultAlertVolume = 0.8;

  Future<void> _set(String key, Future<bool> write) async {
    await write;
    await SettingsSync.touch(prefs, key);
    notifyListeners();
    onLocalChange?.call();
  }

  T _enumValue<T extends Enum>(List<T> values, String key, T fallback) =>
      values.asNameMap()[prefs.getString(key)] ?? fallback;

  // MARK: - 言語

  AppLanguage? get language =>
      AppLanguage.fromCode(prefs.getString(_languageKey));

  Future<void> setLanguage(AppLanguage? language) => _set(
    _languageKey,
    language == null
        ? prefs.remove(_languageKey)
        : prefs.setString(_languageKey, language.code),
  );

  // MARK: - テンキー

  KeypadInputMode get keypadInputMode => _enumValue(
    KeypadInputMode.values,
    _keypadModeKey,
    KeypadInputMode.appendToExisting,
  );

  Future<void> setKeypadInputMode(KeypadInputMode mode) =>
      _set(_keypadModeKey, prefs.setString(_keypadModeKey, mode.name));

  /// 起動時にスタートアップ画面を出すか（既定はオン）。
  bool get showStartupScreen => prefs.getBool(_showStartupScreenKey) ?? true;
  Future<void> setShowStartupScreen(bool value) =>
      _set(_showStartupScreenKey, prefs.setBool(_showStartupScreenKey, value));

  bool get hapticEnabled => prefs.getBool(_hapticEnabledKey) ?? true;
  Future<void> setHapticEnabled(bool value) =>
      _set(_hapticEnabledKey, prefs.setBool(_hapticEnabledKey, value));

  FeedbackStrength get hapticStrength => _enumValue(
    FeedbackStrength.values,
    _hapticStrengthKey,
    FeedbackStrength.medium,
  );
  Future<void> setHapticStrength(FeedbackStrength value) =>
      _set(_hapticStrengthKey, prefs.setString(_hapticStrengthKey, value.name));

  bool get clickEnabled => prefs.getBool(_clickEnabledKey) ?? false;
  Future<void> setClickEnabled(bool value) =>
      _set(_clickEnabledKey, prefs.setBool(_clickEnabledKey, value));

  double get clickVolume => prefs.getDouble(_clickVolumeKey) ?? 0.5;
  Future<void> setClickVolume(double value) =>
      _set(_clickVolumeKey, prefs.setDouble(_clickVolumeKey, value));

  // MARK: - 到着アラート

  bool isAlertEnabled(StopAlertMode mode) =>
      prefs.getBool(_alertModeKey(mode)) ?? mode.defaultEnabled;
  Future<void> setAlertEnabled(StopAlertMode mode, bool value) =>
      _set(_alertModeKey(mode), prefs.setBool(_alertModeKey(mode), value));

  String get alertSoundId => prefs.getString(_alertSoundKey) ?? 'tiptoes';
  Future<void> setAlertSoundId(String id) =>
      _set(_alertSoundKey, prefs.setString(_alertSoundKey, id));

  /// オンなら端末の音量に従い、スライダーの音量は使わない。
  bool get alertFollowsSystemVolume =>
      prefs.getBool(_alertFollowsSystemKey) ?? true;
  Future<void> setAlertFollowsSystemVolume(bool value) => _set(
    _alertFollowsSystemKey,
    prefs.setBool(_alertFollowsSystemKey, value),
  );

  double get alertVolume =>
      prefs.getDouble(_alertVolumeKey) ?? defaultAlertVolume;
  Future<void> setAlertVolume(double value) =>
      _set(_alertVolumeKey, prefs.setDouble(_alertVolumeKey, value));

  FeedbackStrength get alertVibrationStrength => _enumValue(
    FeedbackStrength.values,
    _alertVibrationStrengthKey,
    FeedbackStrength.heavy,
  );
  Future<void> setAlertVibrationStrength(FeedbackStrength value) => _set(
    _alertVibrationStrengthKey,
    prefs.setString(_alertVibrationStrengthKey, value.name),
  );

  List<DistanceAlertSlot> get distanceSlots => [
    for (var i = 0; i < DistanceAlertSlot.count; i++)
      DistanceAlertSlot(
        index: i,
        enabled: prefs.getBool(_slotEnabledKey(i)) ?? true,
        meters:
            prefs.getInt(_slotMetersKey(i)) ??
            DistanceAlertSlot.defaultMeters[i],
      ),
  ];

  Future<void> setSlotEnabled(int index, bool value) => _set(
    _slotEnabledKey(index),
    prefs.setBool(_slotEnabledKey(index), value),
  );
  Future<void> setSlotMeters(int index, int meters) =>
      _set(_slotMetersKey(index), prefs.setInt(_slotMetersKey(index), meters));

  // MARK: - 開発者

  static const _verboseLogKey = 'dev.verboseLog';

  /// 位置の更新など量の多いログも書く。端末ごとのものなので同期しない。
  bool get verboseLog => prefs.getBool(_verboseLogKey) ?? false;
  Future<void> setVerboseLog(bool value) async {
    await prefs.setBool(_verboseLogKey, value);
    notifyListeners();
  }

  /// 有効な距離（遠い順）。
  List<int> get activeThresholds => [
    for (final s in distanceSlots)
      if (s.enabled) s.meters,
  ]..sort((a, b) => b.compareTo(a));
}
