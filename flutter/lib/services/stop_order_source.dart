import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/official_stop_order.dart';
import 'app_log.dart';

/// 「停留所順を更新」の結果。
sealed class StopOrderUpdateResult {
  const StopOrderUpdateResult();
}

/// 新しい日付のファイルに差し替えた。
class StopOrderUpdated extends StopOrderUpdateResult {
  const StopOrderUpdated(this.updated);
  final String updated;
}

/// 取れたが、日付が今のファイルと同じか古い。今のファイルのまま。
class StopOrderNotNewer extends StopOrderUpdateResult {
  const StopOrderNotNewer(this.updated);
  final String updated;
}

/// URL が空、通信の失敗、JSON として読めない。今のファイルのまま。
class StopOrderUpdateFailed extends StopOrderUpdateResult {
  const StopOrderUpdateFailed(this.reason);
  final String reason;
}

/// 公式の停留所順のファイル。同梱（`assets/stop_order.json`）と、更新で文書領域に保存したファイルの
/// うち `updated` が新しい方を使う。同梱ファイルは書き換えない。
/// 更新の GET は押したときだけ行い、位置情報は付けない（路線データの同意とは独立）。
class StopOrderSource {
  StopOrderSource({
    Future<String> Function()? bundled,
    Future<Directory> Function()? directory,
    Future<http.Response> Function(Uri url)? get,
    this.url = updateUrl,
  })  : _bundled = bundled ?? (() => rootBundle.loadString(assetPath)),
        _directory = directory ?? getApplicationDocumentsDirectory,
        _get = get ?? ((url) => http.get(url).timeout(const Duration(seconds: 30)));

  /// 更新の取得先。空なら更新しない。ここ以外に URL を書かない。
  static const String updateUrl = '';

  static const String assetPath = 'assets/stop_order.json';
  static const String fileName = 'stop_order.json';

  final String url;
  final Future<String> Function() _bundled;
  final Future<Directory> Function() _directory;
  final Future<http.Response> Function(Uri url) _get;

  OfficialStopOrderFile _current = OfficialStopOrderFile.empty;
  bool _isBundled = true;

  /// 照合に使っている停留所順。
  OfficialStopOrderFile get current => _current;

  /// [current] が同梱か（false なら更新で取得したもの）。
  bool get isBundled => _isBundled;

  Future<File> _file() async {
    final dir = Directory('${(await _directory()).path}/osmBus');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }

  /// 同梱と保存済みを読み、新しい方を使う。同じ日付なら同梱。
  Future<void> load() async {
    var bundled = OfficialStopOrderFile.empty;
    try {
      bundled = OfficialStopOrderFile.fromJson(jsonDecode(await _bundled()));
    } catch (e) {
      AppLog.w('stopOrder', 'bundled unreadable $e');
    }
    OfficialStopOrderFile? saved;
    try {
      final f = await _file();
      if (await f.exists()) saved = OfficialStopOrderFile.fromJson(jsonDecode(await f.readAsString()));
    } catch (e) {
      AppLog.w('stopOrder', 'saved unreadable $e');
    }
    if (saved != null && saved.isNewerThan(bundled)) {
      _current = saved;
      _isBundled = false;
    } else {
      _current = bundled;
      _isBundled = true;
    }
    AppLog.i('stopOrder', 'using ${_current.updated} bundled=$_isBundled routes=${_current.routes.length}');
  }

  /// [url] から取り、`updated` が今より新しいときだけ差し替えて保存する。
  Future<StopOrderUpdateResult> update() async {
    if (url.isEmpty) return const StopOrderUpdateFailed('no update URL');
    final String body;
    try {
      final response = await _get(Uri.parse(url));
      if (response.statusCode != 200) return StopOrderUpdateFailed('HTTP ${response.statusCode}');
      body = utf8.decode(response.bodyBytes);
    } catch (e) {
      AppLog.w('stopOrder', 'update failed $e');
      return StopOrderUpdateFailed('$e');
    }
    return adopt(body);
  }

  /// 取得した本文を採用するか決める。読めない、または新しくなければ今のまま。
  Future<StopOrderUpdateResult> adopt(String body) async {
    final OfficialStopOrderFile fetched;
    try {
      fetched = OfficialStopOrderFile.fromJson(jsonDecode(body));
    } catch (e) {
      AppLog.w('stopOrder', 'fetched unreadable $e');
      return StopOrderUpdateFailed('$e');
    }
    if (!fetched.isNewerThan(_current)) return StopOrderNotNewer(_current.updated);
    try {
      await (await _file()).writeAsString(jsonEncode(fetched.toJson()), flush: true);
    } catch (e) {
      return StopOrderUpdateFailed('$e');
    }
    _current = fetched;
    _isBundled = false;
    AppLog.i('stopOrder', 'updated to ${fetched.updated} routes=${fetched.routes.length}');
    return StopOrderUpdated(fetched.updated);
  }
}
