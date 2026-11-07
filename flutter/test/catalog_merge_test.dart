import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/services/route_catalog_store.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const hanoi = GeoPoint(21.0285, 105.8542);
const saigon = GeoPoint(10.7769, 106.7009);

RouteRecord anchored(int id, GeoPoint anchor, {DateTime? updatedAt, List<GeoPoint>? stops}) =>
    route(id: id, ref: '$id', stops: stops ?? [anchor, GeoPoint(anchor.latitude + kmLat, anchor.longitude)])
        .copyWith(
      anchorLatitude: anchor.latitude,
      anchorLongitude: anchor.longitude,
      updatedAt: updatedAt,
    );

void main() {
  final now = DateTime.utc(2026, 10, 25, 9);

  group('マージ', () {
    test('都市 A と都市 B の和は両方残る', () {
      final merged = CatalogOps.merge(
        CatalogSnapshot(routes: [anchored(1, hanoi)]),
        CatalogSnapshot(routes: [anchored(2, saigon)]),
        now: now,
      );
      expect(merged.routes.map((r) => r.relationId), [1, 2]);
      expect(merged.syncedAt, now);
    });

    test('同じ id は updatedAt が新しい形状を残す', () {
      final oldShape = [hanoi, GeoPoint(hanoi.latitude + kmLat, hanoi.longitude)];
      final newShape = [hanoi, GeoPoint(hanoi.latitude, hanoi.longitude + 0.01)];
      final local = anchored(3, hanoi, updatedAt: DateTime.utc(2026, 1, 1), stops: oldShape);
      final remote = anchored(3, hanoi, updatedAt: DateTime.utc(2026, 6, 1), stops: newShape);

      final pulled = CatalogOps.merge(
        CatalogSnapshot(routes: [local]),
        CatalogSnapshot(routes: [remote]),
        now: now,
      );
      expect(pulled.routes.single.polylineSegments.single, newShape);

      final pushed = CatalogOps.merge(
        CatalogSnapshot(routes: [remote]),
        CatalogSnapshot(routes: [local]),
        now: now,
      );
      expect(pushed.routes.single.polylineSegments.single, newShape);
    });

    test('updatedAt が片方に無ければ形状のある方', () {
      final withShape = anchored(4, hanoi);
      final withoutShape = anchored(4, hanoi, updatedAt: DateTime.utc(2026, 6, 1))
          .copyWith(hasGeometry: false, stops: const [], polylineSegments: const []);
      final merged = CatalogOps.merge(
        CatalogSnapshot(routes: [withoutShape]),
        CatalogSnapshot(routes: [withShape]),
        now: now,
      );
      expect(merged.routes.single.hasGeometry, isTrue);
    });
  });

  group('dropMissing', () {
    final snapshot = CatalogSnapshot(routes: [
      anchored(1, hanoi),
      anchored(2, saigon),
      anchored(5, GeoPoint(hanoi.latitude + 0.2, hanoi.longitude)),
      route(id: 6, ref: '6', stops: [hanoi, saigon]),
    ]);
    const tags = [CatalogTag(id: 1, ref: '1', name: 'Route 1')];

    CatalogSnapshot apply({required bool dropMissing}) => CatalogOps.applyTags(
          snapshot,
          tags,
          origin: hanoi,
          dropMissing: dropMissing,
          now: now,
          distance: Geo.distance,
        );

    test('80km を超えるアンカーの路線は見出しに無くても消えない、80km 以内は消える', () {
      final ids = apply(dropMissing: true).routes.map((r) => r.relationId).toSet();
      expect(ids, containsAll([1, 2, 6]));
      expect(ids, isNot(contains(5)));
    });

    test('dropMissing: false では消さない', () {
      expect(apply(dropMissing: false).routes, hasLength(4));
    });

    test('タイムスタンプが変わったら形状を捨てる、同じなら残す', () {
      final base = CatalogSnapshot(routes: [anchored(1, hanoi).copyWith(osmTimestamp: 't1')]);
      CatalogSnapshot withTimestamp(String ts) => CatalogOps.applyTags(
            base,
            [CatalogTag(id: 1, ref: '1', name: 'Route 1', timestamp: ts)],
            origin: hanoi,
            dropMissing: true,
            now: now,
            distance: Geo.distance,
          );
      expect(withTimestamp('t1').routes.single.hasGeometry, isTrue);
      expect(withTimestamp('t2').routes.single.hasGeometry, isFalse);
      expect(withTimestamp('t2').routes.single.updatedAt, now);
    });
  });

  group('Swift のファイル', () {
    test('syncedAt が数値 600000000 でも読め、updatedAt の無いレコードも読める', () {
      const json = '''
      {"syncedAt": 600000000, "routes": [
        {"relationId": 42, "ref": "35A", "name": "35A", "from": null, "to": null,
         "osmTimestamp": "2024-01-01T00:00:00Z",
         "stops": [{"id": 1, "name": "Ben xe", "latitude": 21.02, "longitude": 105.84}],
         "polylineSegments": [[{"latitude": 21.02, "longitude": 105.84}]],
         "hasGeometry": true, "unknownKey": 1}
      ]}''';
      final snapshot = CatalogSnapshot.fromJson(jsonDecode(json));
      expect(snapshot.syncedAt, DateTime.utc(2001).add(const Duration(seconds: 600000000)));
      expect(snapshot.syncedAt, DateTime.utc(2020, 1, 6, 10, 40));
      final record = snapshot.routes.single;
      expect(record.updatedAt, isNull);
      expect(record.anchor, isNull);
      expect(record.stops.single.name, 'Ben xe');
    });

    test('schemaVersion が 1 以外、routes が配列でなければ拒否', () {
      expect(() => CatalogSnapshot.fromJson({'schemaVersion': 2, 'routes': []}), throwsFormatException);
      expect(() => CatalogSnapshot.fromJson({'schemaVersion': 1, 'routes': {}}), throwsFormatException);
    });
  });

  group('ストアとバックアップ', () {
    late Directory dir;
    late RouteCatalogStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('osmbus_test');
      store = RouteCatalogStore(baseDirectory: () async => dir);
    });

    tearDown(() => dir.delete(recursive: true));

    test('書き出して統合で読み戻すと relation が欠けない', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller =
          TripController(prefs: prefs, store: store, sync: const UnsupportedCatalogSync());
      await store.save(CatalogSnapshot(routes: [anchored(1, hanoi), anchored(2, saigon)]));
      final exported = RouteCatalogStore.encode(await store.load());

      await store.save(CatalogSnapshot(routes: [anchored(3, hanoi)]));
      final result = await controller.importBackupText(exported, ImportMode.merge);
      expect(result.error, isNull);
      expect((await store.load()).routes.map((r) => r.relationId).toSet(), {1, 2, 3});

      final bad = await controller.importBackupText('{"schemaVersion": 9, "routes": []}', ImportMode.replace);
      expect(bad.error, isNotNull);
      expect((await store.load()).routes, hasLength(3));

      final replaced = await controller.importBackupText(exported, ImportMode.replace);
      expect(replaced.routeCount, 2);
      controller.dispose();
    });

    test('ファイルに書いて読み直せる', () async {
      await store.save(CatalogSnapshot(syncedAt: now, routes: [anchored(1, hanoi, updatedAt: now)]));
      final reread = RouteCatalogStore(baseDirectory: () async => dir);
      final snapshot = await reread.load();
      expect(snapshot.syncedAt, now);
      expect(snapshot.routes.single.updatedAt, now);
      final raw = jsonDecode(await (await reread.file()).readAsString()) as Map;
      expect(raw['schemaVersion'], 1);
      expect(raw['dateEncoding'], 'iso8601');
    });

    test('保管庫は置き換え・削除・形状の取り消しでも路線を失わない', () async {
      await store.save(CatalogSnapshot(routes: [anchored(1, hanoi), anchored(2, saigon)]));
      await store.save(CatalogSnapshot(routes: [anchored(1, hanoi).copyWith(hasGeometry: false, stops: const [])]));
      await store.delete();

      final archive = await RouteCatalogStore(baseDirectory: () async => dir).loadArchive();
      expect(archive.routes.map((r) => r.relationId).toSet(), {1, 2});
      expect(archive.routes.every((r) => r.hasGeometry && r.stops.isNotEmpty), isTrue);
    });

    test('壊れた正本は脇へ移し、保管庫から立て直す', () async {
      await store.save(CatalogSnapshot(routes: [anchored(1, hanoi), anchored(2, saigon)]));
      final main = await store.file();
      await main.writeAsString('{"routes": [ {"relationId": 1, ');

      final reopened = RouteCatalogStore(baseDirectory: () async => dir);
      expect((await reopened.load()).routes.map((r) => r.relationId).toSet(), {1, 2});
      final setAside = dir.listSync(recursive: true).where((f) => f.path.contains('.corrupt-'));
      expect(setAside, hasLength(1));
    });

    test('保管庫の形状は OSM の版が同じ路線だけに戻す', () {
      final kept = anchored(1, hanoi).copyWith(osmTimestamp: '2026-01-01T00:00:00Z');
      final archive = CatalogSnapshot(routes: [kept, anchored(2, hanoi).copyWith(osmTimestamp: 'old')]);
      final bare = CatalogSnapshot(routes: [
        kept.copyWith(hasGeometry: false, stops: const [], polylineSegments: const []),
        anchored(2, hanoi).copyWith(osmTimestamp: 'new', hasGeometry: false, stops: const []),
      ]);
      final restored = CatalogOps.restoreGeometry(bare, archive);
      expect(restored.routes[0].hasGeometry, isTrue);
      expect(restored.routes[0].stops, isNotEmpty);
      expect(restored.routes[1].hasGeometry, isFalse);
    });

    test('iOS 以外の同期は落ちずに未対応を返す', () async {
      const sync = UnsupportedCatalogSync();
      await sync.checkAvailability();
      expect(sync.isSupported, isFalse);
      expect(sync.mergeAndPush(), throwsA(isA<SyncUnavailableException>()));
    });
  });
}
