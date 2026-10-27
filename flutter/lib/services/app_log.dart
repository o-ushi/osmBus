import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/route_catalog.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  const LogEntry(this.time, this.level, this.category, this.message);

  final DateTime time;
  final LogLevel level;
  final String category;
  final String message;

  String get levelMark => switch (level) {
        LogLevel.debug => 'D',
        LogLevel.info => 'I',
        LogLevel.warning => 'W',
        LogLevel.error => 'E',
      };

  @override
  String toString() => '${time.toIso8601String()} $levelMark [$category] $message';
}

/// アプリのログ（Swift は `os.Logger` で Console.app に出していたもの）。
/// 端末内のファイルに書き、開発者画面から共有シートで送れる。
/// 位置は 0.001 度（約 100m）に丸めて書く。
class AppLog extends ChangeNotifier {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const int memoryLimit = 500;
  static const int fileLimitBytes = 512 * 1024;
  static const String fileName = 'osmbus.log';

  final List<LogEntry> _recent = [];
  Directory? _dir;
  Future<void> _writing = Future.value();
  final StringBuffer _pending = StringBuffer();
  Timer? _flushTimer;

  /// 位置の更新など、量の多いログも書く。
  bool verbose = false;

  List<LogEntry> get recent => List.unmodifiable(_recent);

  /// 起動時に呼ぶ。呼ばなければ（テストなど）メモリにだけ残す。
  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/osmBus/logs');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
    } catch (_) {}
  }

  static String coord(GeoPoint? p) =>
      p == null ? '-' : '${p.latitude.toStringAsFixed(3)},${p.longitude.toStringAsFixed(3)}';

  static void d(String category, String message) {
    if (instance.verbose) instance.add(LogLevel.debug, category, message);
  }

  static void i(String category, String message) => instance.add(LogLevel.info, category, message);
  static void w(String category, String message) => instance.add(LogLevel.warning, category, message);

  static void e(String category, String message, [Object? error, StackTrace? stack]) {
    final detail = [
      message,
      if (error != null) '$error',
      if (stack != null) stack.toString().split('\n').take(12).join('\n'),
    ].join('\n');
    instance.add(LogLevel.error, category, detail);
  }

  void add(LogLevel level, String category, String message) {
    final entry = LogEntry(DateTime.now(), level, category, message);
    _recent.add(entry);
    if (_recent.length > memoryLimit) _recent.removeRange(0, _recent.length - memoryLimit);
    if (kDebugMode) debugPrint('osmBus $entry');
    if (_dir != null) {
      _pending.writeln(entry);
      // 書き込みはまとめて行う。エラーはすぐ書く（直後に落ちても残るように）。
      if (level == LogLevel.error) {
        unawaited(flush());
      } else {
        _flushTimer ??= Timer(const Duration(seconds: 2), () => unawaited(flush()));
      }
    }
    notifyListeners();
  }

  File? get _file => _dir == null ? null : File('${_dir!.path}/$fileName');
  File? get _previous => _dir == null ? null : File('${_dir!.path}/$fileName.1');

  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final file = _file;
    if (file == null || _pending.isEmpty) return _writing;
    final text = _pending.toString();
    _pending.clear();
    return _writing = _writing.then((_) async {
      try {
        if (await file.exists() && await file.length() > fileLimitBytes) {
          await file.rename(_previous!.path);
        }
        await file.writeAsString(text, mode: FileMode.append, flush: true);
      } catch (_) {}
    });
  }

  /// 送る用の 1 ファイル。先頭に [header]（端末・アプリの情報）、続けて古い順のログ。
  Future<File> export(String header) async {
    await flush();
    await _writing;
    final buffer = StringBuffer(header)..writeln()..writeln('---');
    var fromFiles = false;
    for (final f in [_previous, _file]) {
      if (f != null && await f.exists()) {
        buffer.write(await f.readAsString());
        fromFiles = true;
      }
    }
    if (!fromFiles) {
      for (final entry in _recent) {
        buffer.writeln(entry);
      }
    }
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final file = File(
      '${dir.path}/osmBus-log-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}.txt',
    );
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  Future<void> clear() async {
    _recent.clear();
    _pending.clear();
    await _writing;
    for (final f in [_file, _previous]) {
      try {
        if (f != null && await f.exists()) await f.delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// ログファイルの合計サイズ（バイト）。
  Future<int> sizeOnDisk() async {
    var total = 0;
    for (final f in [_file, _previous]) {
      if (f != null && await f.exists()) total += await f.length();
    }
    return total;
  }
}
