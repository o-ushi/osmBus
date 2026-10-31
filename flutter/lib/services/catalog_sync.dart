import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/route_catalog.dart';
import '../state/places_store.dart';
import 'route_catalog_store.dart';
import 'app_log.dart';

enum SyncUnavailableReason { notIOS, iCloudUnavailable }

/// §5.2 正本 JSON をファイルとして同期する。
abstract class CatalogSync {
  static const String containerId = 'iCloud.com.osamushikubo.osmBus';
  static const String relativePath = 'Documents/bus-route-catalog.json';

  /// 登録済みの場所と目的地の履歴。路線の正本とは別のファイルにする。
  static const String personalRelativePath = 'Documents/osmBus-places.json';

  /// iOS 以外では iCloud の実装を作らない。
  factory CatalogSync.forPlatform(RouteCatalogStore store) =>
      Platform.isIOS ? ICloudCatalogSync(store) : const UnsupportedCatalogSync();

  /// iOS かつ iCloud が使えるときだけ true。[checkAvailability] の後に確定する。
  bool get isSupported;

  SyncUnavailableReason? get unavailableReason;

  Future<void> checkAvailability();

  Future<void> pushLocal();

  Future<CatalogSnapshot?> pullRemote();

  Future<CatalogSnapshot> mergeAndPush();

  /// iCloud 側の場所・履歴と [local] を統合して書き戻し、統合結果を返す。
  Future<PersonalData> mergePersonal(PersonalData local);
}

class SyncUnavailableException implements Exception {
  const SyncUnavailableException(this.reason);
  final SyncUnavailableReason reason;

  @override
  String toString() => 'SyncUnavailableException($reason)';
}

class UnsupportedCatalogSync implements CatalogSync {
  const UnsupportedCatalogSync();

  @override
  bool get isSupported => false;

  @override
  SyncUnavailableReason get unavailableReason => SyncUnavailableReason.notIOS;

  @override
  Future<void> checkAvailability() async {}

  @override
  Future<void> pushLocal() async => throw const SyncUnavailableException(SyncUnavailableReason.notIOS);

  @override
  Future<CatalogSnapshot?> pullRemote() async =>
      throw const SyncUnavailableException(SyncUnavailableReason.notIOS);

  @override
  Future<CatalogSnapshot> mergeAndPush() async =>
      throw const SyncUnavailableException(SyncUnavailableReason.notIOS);

  @override
  Future<PersonalData> mergePersonal(PersonalData local) async =>
      throw const SyncUnavailableException(SyncUnavailableReason.notIOS);
}

/// iCloud Documents（ubiquity container）へ同じ JSON を置く。CloudKit は使わない。
class ICloudCatalogSync implements CatalogSync {
  ICloudCatalogSync(this.store);

  static const Duration transferTimeout = Duration(seconds: 60);

  final RouteCatalogStore store;
  bool? _available;

  @override
  bool get isSupported => _available == true;

  @override
  SyncUnavailableReason? get unavailableReason =>
      _available == true ? null : SyncUnavailableReason.iCloudUnavailable;

  @override
  Future<void> checkAvailability() async {
    try {
      await ICloudStorage.gather(containerId: CatalogSync.containerId);
      _available = true;
    } catch (e) {
      AppLog.i('sync', 'iCloud unavailable $e');
      // コンテナが無い、未サインイン、権限なし。どれでも起動は続ける。
      _available = false;
    }
  }

  void _requireAvailable() {
    if (_available != true) {
      throw const SyncUnavailableException(SyncUnavailableReason.iCloudUnavailable);
    }
  }

  Future<File> _tempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name');
  }

  Future<void> _waitFor(Future<void> Function(void Function(Stream<double>)) start) async {
    final done = Completer<void>();
    await start((stream) {
      stream.listen(
        (_) {},
        onError: (Object e) {
          if (!done.isCompleted) done.completeError(e);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
    });
    await done.future.timeout(transferTimeout);
  }

  @override
  Future<void> pushLocal() async {
    _requireAvailable();
    await _push(await store.load());
  }

  Future<void> _push(CatalogSnapshot snapshot) =>
      _upload(CatalogSync.relativePath, 'bus-route-catalog.upload.json', RouteCatalogStore.encode(snapshot));

  Future<void> _upload(String relativePath, String tempName, String text) async {
    final tmp = await _tempFile(tempName);
    await tmp.writeAsString(text, flush: true);
    await ICloudStorage.upload(
      containerId: CatalogSync.containerId,
      filePath: tmp.path,
      destinationRelativePath: relativePath,
    );
  }

  /// まだ無ければ null。
  Future<String?> _download(String relativePath, String tempName) async {
    final files = await ICloudStorage.gather(containerId: CatalogSync.containerId);
    if (!files.any((f) => f.relativePath == relativePath)) return null;
    final tmp = await _tempFile(tempName);
    try {
      await _waitFor((onProgress) => ICloudStorage.download(
            containerId: CatalogSync.containerId,
            relativePath: relativePath,
            destinationFilePath: tmp.path,
            onProgress: onProgress,
          ));
    } on PlatformException catch (e) {
      if (e.code == PlatformExceptionCode.fileNotFound) return null;
      rethrow;
    }
    return tmp.readAsString();
  }

  @override
  Future<CatalogSnapshot?> pullRemote() async {
    _requireAvailable();
    final text = await _download(CatalogSync.relativePath, 'bus-route-catalog.download.json');
    return text == null ? null : CatalogSnapshot.fromJson(jsonDecode(text));
  }

  @override
  Future<CatalogSnapshot> mergeAndPush() async {
    _requireAvailable();
    final remote = await pullRemote();
    final now = DateTime.now().toUtc();
    final merged = await store.update(
      (local) => remote == null
          ? local.copyWith(syncedAt: now)
          : CatalogOps.merge(local, remote, now: now),
      source: CatalogSaveSource.sync,
    );
    await _push(merged);
    return merged;
  }

  @override
  Future<PersonalData> mergePersonal(PersonalData local) async {
    _requireAvailable();
    final text = await _download(CatalogSync.personalRelativePath, 'osmBus-places.download.json');
    final merged = text == null
        ? local
        : PersonalData.merge(local, PersonalData.fromJson(jsonDecode(text)), now: DateTime.now().toUtc());
    await _upload(CatalogSync.personalRelativePath, 'osmBus-places.upload.json', jsonEncode(merged.toJson()));
    return merged;
  }
}
