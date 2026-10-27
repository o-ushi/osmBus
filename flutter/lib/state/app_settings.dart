import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const DistanceAlertSlot({required this.index, required this.enabled, required this.meters});

  static const int count = 3;
  static const List<int> defaultMeters = [1000, 400, 100];
  static const List<int> presets = [50, 100, 150, 200, 300, 400, 500, 750, 1000, 1500, 2000];

  final int index;
  final bool enabled;
  final int meters;
}

/// アプリ全体の設定。値は SharedPreferences に置く。
class AppSettings extends ChangeNotifier {
  AppSettings(this.prefs);

  final SharedPreferences prefs;

  static const _languageKey = 'appLanguage';
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

  Future<void> _set(Future<bool> write) async {
    await write;
    notifyListeners();
  }

  T _enumValue<T extends Enum>(List<T> values, String key, T fallback) =>
      values.asNameMap()[prefs.getString(key)] ?? fallback;

  // MARK: - 言語

  AppLanguage? get language => AppLanguage.fromCode(prefs.getString(_languageKey));

  Future<void> setLanguage(AppLanguage? language) => _set(
        language == null ? prefs.remove(_languageKey) : prefs.setString(_languageKey, language.code),
      );

  // MARK: - テンキー

  KeypadInputMode get keypadInputMode =>
      _enumValue(KeypadInputMode.values, _keypadModeKey, KeypadInputMode.appendToExisting);

  Future<void> setKeypadInputMode(KeypadInputMode mode) => _set(prefs.setString(_keypadModeKey, mode.name));

  bool get hapticEnabled => prefs.getBool(_hapticEnabledKey) ?? true;
  Future<void> setHapticEnabled(bool value) => _set(prefs.setBool(_hapticEnabledKey, value));

  FeedbackStrength get hapticStrength =>
      _enumValue(FeedbackStrength.values, _hapticStrengthKey, FeedbackStrength.medium);
  Future<void> setHapticStrength(FeedbackStrength value) => _set(prefs.setString(_hapticStrengthKey, value.name));

  bool get clickEnabled => prefs.getBool(_clickEnabledKey) ?? false;
  Future<void> setClickEnabled(bool value) => _set(prefs.setBool(_clickEnabledKey, value));

  double get clickVolume => prefs.getDouble(_clickVolumeKey) ?? 0.5;
  Future<void> setClickVolume(double value) => _set(prefs.setDouble(_clickVolumeKey, value));

  // MARK: - 到着アラート

  bool isAlertEnabled(StopAlertMode mode) => prefs.getBool(_alertModeKey(mode)) ?? mode.defaultEnabled;
  Future<void> setAlertEnabled(StopAlertMode mode, bool value) => _set(prefs.setBool(_alertModeKey(mode), value));

  String get alertSoundId => prefs.getString(_alertSoundKey) ?? 'tiptoes';
  Future<void> setAlertSoundId(String id) => _set(prefs.setString(_alertSoundKey, id));

  /// オンなら端末の音量に従い、スライダーの音量は使わない。
  bool get alertFollowsSystemVolume => prefs.getBool(_alertFollowsSystemKey) ?? true;
  Future<void> setAlertFollowsSystemVolume(bool value) => _set(prefs.setBool(_alertFollowsSystemKey, value));

  double get alertVolume => prefs.getDouble(_alertVolumeKey) ?? defaultAlertVolume;
  Future<void> setAlertVolume(double value) => _set(prefs.setDouble(_alertVolumeKey, value));

  FeedbackStrength get alertVibrationStrength =>
      _enumValue(FeedbackStrength.values, _alertVibrationStrengthKey, FeedbackStrength.heavy);
  Future<void> setAlertVibrationStrength(FeedbackStrength value) =>
      _set(prefs.setString(_alertVibrationStrengthKey, value.name));

  List<DistanceAlertSlot> get distanceSlots => [
        for (var i = 0; i < DistanceAlertSlot.count; i++)
          DistanceAlertSlot(
            index: i,
            enabled: prefs.getBool(_slotEnabledKey(i)) ?? true,
            meters: prefs.getInt(_slotMetersKey(i)) ?? DistanceAlertSlot.defaultMeters[i],
          ),
      ];

  Future<void> setSlotEnabled(int index, bool value) => _set(prefs.setBool(_slotEnabledKey(index), value));
  Future<void> setSlotMeters(int index, int meters) => _set(prefs.setInt(_slotMetersKey(index), meters));

  // MARK: - 開発者

  static const _verboseLogKey = 'dev.verboseLog';

  /// 位置の更新など量の多いログも書く。
  bool get verboseLog => prefs.getBool(_verboseLogKey) ?? false;
  Future<void> setVerboseLog(bool value) => _set(prefs.setBool(_verboseLogKey, value));

  /// 有効な距離（遠い順）。
  List<int> get activeThresholds =>
      [for (final s in distanceSlots) if (s.enabled) s.meters]..sort((a, b) => b.compareTo(a));
}
