import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/route_catalog.dart';
import 'geo.dart';
import 'overpass_api.dart';
import 'route_catalog_store.dart';
import 'app_log.dart';

sealed class DownloadActivity {
  const DownloadActivity();
}

class DownloadIdle extends DownloadActivity {
  const DownloadIdle();
}

class DownloadWorking extends DownloadActivity {
  const DownloadWorking(this.done, this.total);
  final int done;
  final int total;
}

/// 完了。[geometryCount] は形状付きの路線数。
class DownloadFinished extends DownloadActivity {
  const DownloadFinished(this.geometryCount, {required this.isUpdate});
  final int geometryCount;
  final bool isUpdate;
}

enum DownloadFailure { consentRequired, noRoutesNearby, network }

class DownloadFailed extends DownloadActivity {
  const DownloadFailed(this.reason, [this.detail]);
  final DownloadFailure reason;
  final String? detail;
}

/// §4 の取得。同意がオンのときだけ通信する。
class RouteCatalogDownloader extends ChangeNotifier {
  RouteCatalogDownloader({
    required this.store,
    required this.consentGranted,
    OverpassApi? api,
    this.chunkDelay = const Duration(milliseconds: 400),
  }) : api = api ?? OverpassApi();

  static const int chunkSize = 4;

  final RouteCatalogStore store;
  final OverpassApi api;
  final bool Function() consentGranted;
  final Duration chunkDelay;

  DownloadActivity _activity = const DownloadIdle();
  int _generation = 0;

  DownloadActivity get activity => _activity;
  bool get isWorking => _activity is DownloadWorking;

  void _set(DownloadActivity activity) {
    _activity = activity;
    notifyListeners();
  }

  Future<void> downloadAll(GeoPoint near) => _run(near, dropMissing: false);

  Future<void> update(GeoPoint near) => _run(near, dropMissing: true);

  void cancel() {
    _generation++;
    if (isWorking) _set(const DownloadIdle());
  }

  Future<void> _run(GeoPoint near, {required bool dropMissing}) async {
    final generation = ++_generation;
    bool cancelled() => generation != _generation;

    if (!consentGranted()) {
      _set(const DownloadFailed(DownloadFailure.consentRequired));
      return;
    }
    _set(const DownloadWorking(0, 0));
    AppLog.i('download', '${dropMissing ? 'update' : 'download'} near ${AppLog.coord(near)}');
    try {
      final tags = await api.fetchCatalog(near);
      if (cancelled()) return;
      if (tags.isEmpty) {
        _set(const DownloadFailed(DownloadFailure.noRoutesNearby));
        return;
      }
      final archive = await store.loadArchive();
      final applied = await store.update((current) => CatalogOps.restoreGeometry(
            CatalogOps.applyTags(
              current,
              tags,
              origin: near,
              dropMissing: dropMissing,
              now: DateTime.now().toUtc(),
              distance: Geo.distance,
            ),
            archive,
          ));
      final pending = [
        for (final r in applied.routes)
          if (!r.hasGeometry) r.relationId,
      ];
      await _downloadGeometry(pending, near, cancelled);
      if (cancelled()) return;
      final snapshot = await store.load();
      AppLog.i('download', 'finished routes=${snapshot.routes.length} geometry=${snapshot.geometryCount}');
      _set(DownloadFinished(snapshot.geometryCount, isUpdate: dropMissing));
    } catch (e) {
      if (cancelled()) return;
      AppLog.w('download', 'failed $e');
      _set(DownloadFailed(DownloadFailure.network, '$e'));
    }
  }

  Future<void> _downloadGeometry(List<int> ids, GeoPoint origin, bool Function() cancelled) async {
    final total = ids.length;
    _set(DownloadWorking(0, total));
    var done = 0;
    for (var index = 0; index < ids.length; index += chunkSize) {
      if (cancelled() || !consentGranted()) return;
      final chunk = ids.sublist(index, (index + chunkSize).clamp(0, ids.length));
      final details = await _detailsAllowingSplit(chunk, cancelled);
      if (cancelled()) return;
      if (details.isNotEmpty) {
        final byId = {for (final d in details) d.relationId: d};
        final now = DateTime.now().toUtc();
        await store.update((current) => current.copyWith(routes: [
              for (final r in current.routes)
                if (byId[r.relationId] case final d?)
                  CatalogOps.attachGeometry(r, d, now: now, downloadOrigin: origin)
                else
                  r,
            ]));
      }
      done += chunk.length;
      _set(DownloadWorking(done, total));
      if (index + chunkSize < ids.length) await Future<void>.delayed(chunkDelay);
    }
  }

  /// 塊が失敗したら 1 件ずつ取り直す。1 件の失敗は飛ばす。
  Future<List<RouteDetail>> _detailsAllowingSplit(List<int> ids, bool Function() cancelled) async {
    try {
      return await api.fetchDetails(ids);
    } catch (_) {
      if (ids.length < 2) return const [];
      final collected = <RouteDetail>[];
      for (final id in ids) {
        if (cancelled()) break;
        try {
          collected.addAll(await api.fetchDetails([id]));
        } catch (_) {}
      }
      return collected;
    }
  }
}
