import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/route_catalog.dart';
import 'route_catalog_store.dart';

enum SyncUnavailableReason { notIOS, iCloudUnavailable }

/// §5.2 正本 JSON をファイルとして同期する。
abstract class CatalogSync {
  static const String containerId = 'iCloud.com.osamushikubo.osmBus';
  static const String relativePath = 'Documents/bus-route-catalog.json';

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
    } catch (_) {
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

  Future<void> _push(CatalogSnapshot snapshot) async {
    final tmp = await _tempFile('bus-route-catalog.upload.json');
    await tmp.writeAsString(RouteCatalogStore.encode(snapshot), flush: true);
    await ICloudStorage.upload(
      containerId: CatalogSync.containerId,
      filePath: tmp.path,
      destinationRelativePath: CatalogSync.relativePath,
    );
  }

  @override
  Future<CatalogSnapshot?> pullRemote() async {
    _requireAvailable();
    final files = await ICloudStorage.gather(containerId: CatalogSync.containerId);
    if (!files.any((f) => f.relativePath == CatalogSync.relativePath)) return null;
    final tmp = await _tempFile('bus-route-catalog.download.json');
    try {
      await _waitFor((onProgress) => ICloudStorage.download(
            containerId: CatalogSync.containerId,
            relativePath: CatalogSync.relativePath,
            destinationFilePath: tmp.path,
            onProgress: onProgress,
          ));
    } on PlatformException catch (e) {
      if (e.code == PlatformExceptionCode.fileNotFound) return null;
      rethrow;
    }
    return CatalogSnapshot.fromJson(jsonDecode(await tmp.readAsString()));
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
}
