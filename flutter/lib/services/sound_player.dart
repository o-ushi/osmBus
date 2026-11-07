import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../state/app_settings.dart';
import 'app_log.dart';

/// 到着アラームの音（Swift の `AlertSoundCatalog`）。
/// iOS は Swift と同じ公開システムサウンドを鳴らす。無ければ（Android・シミュレータ）合成音。
class AlertSound {
  const AlertSound(this.id, this.iosPath, this.tones);

  final String id;

  /// `/System/Library/Audio/UISounds/` からの相対パス。
  final String iosPath;

  /// 合成音の (周波数 Hz, 長さ ms)。周波数 0 は無音。
  final List<(double, int)> tones;

  static const List<AlertSound> all = [
    AlertSound('alarm', 'sms-received1.caf', [(1319, 110), (0, 40), (1319, 110), (0, 40), (1319, 160)]),
    AlertSound('chime', 'new-mail.caf', [(1047, 180), (784, 260)]),
    AlertSound('ding', 'mail-sent.caf', [(1568, 260)]),
    AlertSound('message', 'ReceivedMessage.caf', [(880, 120), (1175, 200)]),
    AlertSound('confirm', 'jbl_confirm.caf', [(659, 100), (988, 180)]),
    AlertSound('tock', 'Tock.aiff', [(600, 50)]),
    AlertSound('bell', 'Doorbell.caf', [(1319, 220), (1047, 320)]),
    AlertSound('tiptoes', 'New/Tiptoes.caf', [(1568, 90), (0, 50), (1760, 90), (0, 50), (2093, 160)]),
  ];

  static const String defaultId = 'tiptoes';

  static AlertSound byId(String id) => all.firstWhere((s) => s.id == id, orElse: () => all.last);
}

/// キーのクリック音・振動と、到着アラームの再生（Swift の `KeypadHapticManager` / `StopAlertPlayer`）。
class SoundPlayer {
  SoundPlayer({required this.settings});

  final AppSettings settings;

  static const _uiSounds = '/System/Library/Audio/UISounds';

  final AudioPlayer _click = AudioPlayer();
  final Map<String, String> _files = {};
  final List<AudioPlayer> _alarmPlayers = [];
  bool _configured = false;

  /// マナーモードでも、画面オフ・バックグラウンドでも鳴るようにする（Swift の `.playback` + mixWithOthers）。
  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
      android: const AudioContextAndroid(
        usageType: AndroidUsageType.alarm,
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    ));
    await _click.setPlayerMode(PlayerMode.lowLatency);
  }

  // MARK: - キー

  void keyTap() {
    if (settings.hapticEnabled) haptic(settings.hapticStrength);
    if (settings.clickEnabled) unawaited(_playClick(settings.clickVolume));
  }

  void enterKey() => HapticFeedback.mediumImpact();

  void previewClick(double volume) => unawaited(_playClick(volume));

  Future<void> _playClick(double volume) async {
    try {
      await _configure();
      final path = await _synth('click', const [(1200, 20)], decay: true);
      await _click.stop();
      await _click.play(DeviceFileSource(path), volume: volume);
    } catch (e) {
      AppLog.w('sound', 'click failed $e');
    }
  }

  static void haptic(FeedbackStrength strength) {
    switch (strength) {
      case FeedbackStrength.light:
        HapticFeedback.lightImpact();
      case FeedbackStrength.medium:
        HapticFeedback.mediumImpact();
      case FeedbackStrength.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  // MARK: - 到着アラーム

  /// 遠いリングから 1〜3 回鳴らす。前の音と重ならないよう、音の長さに合わせて間を空ける。
  Future<void> playAlarm(int times) async {
    final sound = AlertSound.byId(settings.alertSoundId);
    final volume = settings.alertFollowsSystemVolume ? 1.0 : settings.alertVolume;
    final interval = await _interval(sound);
    for (var i = 0; i < times; i++) {
      if (i > 0) await Future<void>.delayed(interval);
      unawaited(_playAlert(sound, volume));
    }
  }

  void vibrateAlert() => haptic(settings.alertVibrationStrength);

  void previewAlert(String id, {required double volume}) => unawaited(_playAlert(AlertSound.byId(id), volume));

  Future<void> _playAlert(AlertSound sound, double volume) async {
    try {
      await _configure();
      final player = AudioPlayer();
      _alarmPlayers.add(player);
      player.onPlayerComplete.first.then((_) {
        _alarmPlayers.remove(player);
        player.dispose();
      });
      final source = await _source(sound);
      AppLog.i('sound', 'alarm ${sound.id} volume=${volume.toStringAsFixed(2)} file=${source.split('/').last}');
      await player.play(DeviceFileSource(source), volume: volume);
    } catch (e, st) {
      AppLog.e('sound', 'alarm failed ${sound.id}', e, st);
    }
  }

  Future<String> _source(AlertSound sound) async {
    final system = File('$_uiSounds/${sound.iosPath}');
    if (Platform.isIOS && await system.exists()) return system.path;
    return _synth('alert_${sound.id}', sound.tones);
  }

  Future<Duration> _interval(AlertSound sound) async {
    const fallback = Duration(milliseconds: 950);
    final player = AudioPlayer();
    try {
      await player.setSource(DeviceFileSource(await _source(sound)));
      final length = await player.getDuration();
      if (length == null || length == Duration.zero) return fallback;
      final padded = length + const Duration(milliseconds: 50);
      return padded > fallback ? padded : fallback;
    } catch (_) {
      return fallback;
    } finally {
      await player.dispose();
    }
  }

  // MARK: - 合成音

  /// 16bit モノラルの WAV を一時ディレクトリに作る。2 回目からは同じファイル。
  Future<String> _synth(String name, List<(double, int)> tones, {bool decay = false}) async {
    final cached = _files[name];
    if (cached != null) return cached;
    const rate = 44100;
    final samples = <int>[];
    for (final (frequency, ms) in tones) {
      final count = rate * ms ~/ 1000;
      for (var i = 0; i < count; i++) {
        if (frequency == 0) {
          samples.add(0);
          continue;
        }
        final p = i / count;
        // 立ち上がり・立ち下がりを丸めてプチ音を防ぐ。
        final envelope = decay ? math.pow(1 - p, 2).toDouble() : math.min(1.0, math.min(p, 1 - p) * 20);
        samples.add((math.sin(2 * math.pi * frequency * i / rate) * envelope * 0.8 * 32767).round());
      }
    }
    final bytes = BytesBuilder();
    final header = ByteData(44);
    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        header.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + samples.length * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, rate, Endian.little);
    header.setUint32(28, rate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, samples.length * 2, Endian.little);
    bytes.add(header.buffer.asUint8List());
    final data = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(i * 2, samples[i], Endian.little);
    }
    bytes.add(data.buffer.asUint8List());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/osmbus_$name.wav');
    await file.writeAsBytes(bytes.toBytes(), flush: true);
    return _files[name] = file.path;
  }
}
