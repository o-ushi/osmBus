import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/route_catalog.dart';

/// 非同期処理を 1 本ずつ流す単純なロック。
class Mutex {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = completer.future.then<void>((_) {}, onError: (_) {});
    previous.whenComplete(() async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

/// 保存がどこから来たか。同期による保存では同期を再び起こさない。
enum CatalogSaveSource { local, sync }

/// 端末内の正本 `osmBus/bus-route-catalog.json`（§3.1）。
///
/// 保存のたびに、形状付きの路線を別ファイルの保管庫 `Documents/osmBus/bus-route-archive.json` にも足す。
/// 保管庫は増えるだけで、置き換え読み込み・同意撤回・正本の破損でも消えない。
/// 中身は正本と同じ形式なので、そのまま読み込み（マージ）できる。
class RouteCatalogStore {
  RouteCatalogStore({
    Future<Directory> Function()? baseDirectory,
    Future<Directory> Function()? archiveDirectory,
  })  : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
        _archiveDirectory = archiveDirectory ?? baseDirectory ?? getApplicationDocumentsDirectory;

  static const String fileName = 'bus-route-catalog.json';
  static const String archiveFileName = 'bus-route-archive.json';

  final Future<Directory> Function() _baseDirectory;
  final Future<Directory> Function() _archiveDirectory;
  final Mutex _lock = Mutex();
  final StreamController<CatalogSaveSource> _saved = StreamController.broadcast();
  CatalogSnapshot? _cache;
  CatalogSnapshot? _archive;
  int _version = 0;

  /// 保存のたびに進む。計画のキャッシュ判定に使う。
  int get version => _version;

  Stream<CatalogSaveSource> get onSaved => _saved.stream;

  /// 最後に読んだスナップショット。未読なら null。
  CatalogSnapshot? get cached => _cache;

  Future<File> file() async {
    final dir = Directory('${(await _baseDirectory()).path}/osmBus');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }

  Future<File> archiveFile() async {
    final dir = Directory('${(await _archiveDirectory()).path}/osmBus');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$archiveFileName');
  }

  Future<CatalogSnapshot> load() => _lock.run(_loadUnlocked);

  /// 保管庫の中身（形状付きの路線だけ）。
  Future<CatalogSnapshot> loadArchive() => _lock.run(_loadArchiveUnlocked);

  Future<CatalogSnapshot> _loadUnlocked() async {
    final cached = _cache;
    if (cached != null) return cached;
    final f = await file();
    var snapshot = CatalogSnapshot.empty;
    if (await f.exists()) {
      try {
        snapshot = CatalogSnapshot.fromJson(jsonDecode(await f.readAsString()));
      } catch (_) {
        // 壊れた正本は上書きせず脇へ移し、保管庫から立て直す。
        await _setAside(f);
        snapshot = await _loadArchiveUnlocked();
      }
      // 保管庫ができる前に取った形状も、起動時に保管庫へ移しておく。
      try {
        await _archiveUnlocked(snapshot);
      } catch (_) {}
    }
    _cache = snapshot;
    return snapshot;
  }

  Future<CatalogSnapshot> _loadArchiveUnlocked() async {
    final cached = _archive;
    if (cached != null) return cached;
    final f = await archiveFile();
    var archive = CatalogSnapshot.empty;
    if (await f.exists()) {
      try {
        archive = CatalogSnapshot.fromJson(jsonDecode(await f.readAsString()));
      } catch (_) {
        // 読めない保管庫を空で上書きしないよう、先に脇へ移す。
        await _setAside(f);
      }
    }
    _archive = archive;
    return archive;
  }

  static Future<void> _setAside(File f) async {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    try {
      await f.rename('${f.path}.corrupt-$stamp');
    } catch (_) {}
  }

  Future<void> save(CatalogSnapshot snapshot, {CatalogSaveSource source = CatalogSaveSource.local}) =>
      _lock.run(() => _saveUnlocked(snapshot, source));

  /// 読んで変えて書くまでをロックの中で行う。
  Future<CatalogSnapshot> update(
    CatalogSnapshot Function(CatalogSnapshot current) transform, {
    CatalogSaveSource source = CatalogSaveSource.local,
  }) =>
      _lock.run(() async {
        final next = transform(await _loadUnlocked());
        await _saveUnlocked(next, source);
        return next;
      });

  Future<void> _saveUnlocked(CatalogSnapshot snapshot, CatalogSaveSource source) async {
    final f = await file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(encode(snapshot), flush: true);
    await tmp.rename(f.path);
    _cache = CatalogSnapshot(
      syncedAt: snapshot.syncedAt,
      routes: snapshot.routes.where((r) => r.ref.trim().isNotEmpty).toList(),
    );
    _version++;
    try {
      await _archiveUnlocked(snapshot);
    } catch (_) {
      // 保管庫に書けなくても正本の保存は成功として扱う。次の保存で書き直す。
    }
    _saved.add(source);
  }

  Future<void> _archiveUnlocked(CatalogSnapshot snapshot) async {
    final current = await _loadArchiveUnlocked();
    final next = CatalogOps.archive(current, snapshot, now: DateTime.now().toUtc());
    if (identical(next, current)) return;
    final f = await archiveFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(encode(next), flush: true);
    await tmp.rename(f.path);
    _archive = next;
  }

  /// 同意撤回のときだけ呼ぶ。保管庫は残す。
  Future<void> delete() => _lock.run(() async {
        final f = await file();
        if (await f.exists()) await f.delete();
        _cache = CatalogSnapshot.empty;
        _version++;
      });

  static String encode(CatalogSnapshot snapshot) => jsonEncode(snapshot.toJson());
}
