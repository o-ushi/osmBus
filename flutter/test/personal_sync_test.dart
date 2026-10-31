import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/route_catalog_store.dart';
import 'package:osmbus/state/places_store.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hanoi = Destination(name: 'Hồ Gươm', point: GeoPoint(21.0285, 105.8542));
const saigon = Destination(name: 'Bến Thành', point: GeoPoint(10.7726, 106.6980));
const hue = Destination(name: 'Đại Nội', point: GeoPoint(16.4698, 107.5786));

SavedPlace place(String id, Destination d, {DateTime? updatedAt, String? label}) =>
    SavedPlace(id: id, label: label ?? d.name, placeName: d.name, point: d.point, updatedAt: updatedAt);

/// iCloud の代わり。2 台の端末で同じインスタンスを共有する。
class FakeCloud {
  CatalogSnapshot? catalog;
  String? personal;
}

class FakeSync implements CatalogSync {
  FakeSync(this.cloud, this.store);

  final FakeCloud cloud;
  final RouteCatalogStore store;

  @override
  bool get isSupported => true;

  @override
  SyncUnavailableReason? get unavailableReason => null;

  @override
  Future<void> checkAvailability() async {}

  @override
  Future<void> pushLocal() async => cloud.catalog = await store.load();

  @override
  Future<CatalogSnapshot?> pullRemote() async => cloud.catalog;

  @override
  Future<CatalogSnapshot> mergeAndPush() async {
    final remote = cloud.catalog;
    final now = DateTime.now().toUtc();
    final merged = await store.update(
      (local) => remote == null ? local : CatalogOps.merge(local, remote, now: now),
      source: CatalogSaveSource.sync,
    );
    return cloud.catalog = merged;
  }

  @override
  Future<PersonalData> mergePersonal(PersonalData local) async {
    final text = cloud.personal;
    final merged = text == null
        ? local
        : PersonalData.merge(local, PersonalData.fromJson(jsonDecode(text)), now: DateTime.now().toUtc());
    cloud.personal = jsonEncode(merged.toJson());
    return merged;
  }
}

Future<PlacesStore> placesStore(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return PlacesStore(prefs: prefs);
}

void main() {
  final t0 = DateTime.utc(2026, 10, 1);
  final t1 = DateTime.utc(2026, 10, 2);
  final t2 = DateTime.utc(2026, 10, 3);

  group('PersonalData.merge', () {
    test('場所は和集合で、同じ id は新しい編集を残す', () {
      final merged = PersonalData.merge(
        PersonalData(places: [place('a', hanoi, updatedAt: t0, label: '旧'), place('b', saigon, updatedAt: t0)]),
        PersonalData(places: [place('a', hanoi, updatedAt: t1, label: '新'), place('c', hue, updatedAt: t0)]),
        now: t2,
      );
      expect(merged.places.map((p) => p.id), ['a', 'b', 'c']);
      expect(merged.places.first.label, '新');
    });

    test('消した印より古い場所は戻らず、印より後の編集は残る', () {
      final merged = PersonalData.merge(
        PersonalData(places: [place('a', hanoi, updatedAt: t0), place('b', saigon, updatedAt: t2)]),
        PersonalData(deletedPlaces: {'a': t1, 'b': t1}),
        now: t2,
      );
      expect(merged.places.map((p) => p.id), ['b']);
      expect(merged.deletedPlaces.keys, containsAll(['a', 'b']));
    });

    test('古い削除の印は捨てる', () {
      final merged = PersonalData.merge(
        PersonalData(deletedPlaces: {'a': t0}),
        const PersonalData(),
        now: t0.add(PersonalData.tombstoneLifetime + const Duration(days: 1)),
      );
      expect(merged.deletedPlaces, isEmpty);
    });

    test('履歴は新しい順で同じ地点は 1 件、消した時刻より前は落とす', () {
      final merged = PersonalData.merge(
        PersonalData(history: [
          HistoryEntry(destination: hanoi, setAt: t2),
          HistoryEntry(destination: hue, setAt: t0),
        ]),
        PersonalData(
          history: [HistoryEntry(destination: saigon, setAt: t1), HistoryEntry(destination: hanoi, setAt: t1)],
          historyClearedAt: t0,
        ),
        now: t2,
      );
      expect(merged.history.map((e) => e.destination.name), [hanoi.name, saigon.name]);
      expect(merged.history.first.setAt, t2);
      expect(merged.historyClearedAt, t0);
    });

    test('JSON で往復できる', () {
      final data = PersonalData(
        places: [place('a', hanoi, updatedAt: t0)],
        history: [HistoryEntry(destination: saigon, setAt: t1)],
        deletedPlaces: {'z': t1},
        historyClearedAt: t0,
      );
      final back = PersonalData.fromJson(jsonDecode(jsonEncode(data.toJson())));
      expect(back.places.single.updatedAt, t0);
      expect(back.history.single.destination.name, saigon.name);
      expect(back.deletedPlaces, {'z': t1});
      expect(back.historyClearedAt, t0);
      expect(() => PersonalData.fromJson({'places': 'x'}), throwsFormatException);
    });
  });

  group('PlacesStore', () {
    test('削除と履歴の消去が印として残る', () async {
      final store = await placesStore({});
      await store.addPlace(place('a', hanoi));
      await store.addHistory(saigon);
      await store.deletePlace('a');
      await store.clearHistory();
      expect(store.data.deletedPlaces.keys, ['a']);
      expect(store.data.historyClearedAt, isNotNull);
      store.dispose();
    });

    test('反映時に件数を切らない', () async {
      final store = await placesStore({});
      await store.apply(PersonalData(places: [for (var i = 0; i < 5; i++) place('$i', hanoi)]));
      expect(store.places, hasLength(5));
      store.dispose();
    });
  });

  group('バックアップと iCloud', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('osmbus_personal'));
    tearDown(() => dir.delete(recursive: true));

    Future<TripController> device(String name, FakeCloud cloud) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync.iCloudEnabled', true);
      final store = RouteCatalogStore(baseDirectory: () async => Directory('${dir.path}/$name')..createSync());
      return TripController(
        prefs: prefs,
        store: store,
        sync: FakeSync(cloud, store),
        places: PlacesStore(prefs: prefs),
      );
    }

    test('書き出しに場所と履歴が入り、読み込みで戻る', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await device('a', FakeCloud());
      await a.places.addPlace(place('home', hanoi, label: '自宅'));
      await a.places.addHistory(saigon);
      final exported = await a.exportBackupText();
      expect((jsonDecode(exported) as Map)['personal'], isNotNull);

      await a.places.clearAll();
      final result = await a.importBackupText(exported, ImportMode.replace);
      expect(result.error, isNull);
      expect(a.places.places.single.label, '自宅');
      expect(a.places.history.single.destination.name, saigon.name);

      // personal の無い古いファイルは路線だけ読み、場所はそのまま。
      final old = await a.importBackupText('{"routes": []}', ImportMode.merge);
      expect(old.error, isNull);
      expect(a.places.places, hasLength(1));

      // personal が壊れていれば何も変えない。
      final bad = await a.importBackupText('{"routes": [], "personal": {"places": 1}}', ImportMode.replace);
      expect(bad.error, isNotNull);
      expect(a.places.places, hasLength(1));
      a.dispose();
    });

    test('2 台の間で追加と削除が伝わる', () async {
      final cloud = FakeCloud();
      SharedPreferences.setMockInitialValues({});
      final a = await device('a', cloud);
      await a.places.addPlace(place('home', hanoi, updatedAt: t0, label: '自宅'));
      await a.places.addHistory(saigon);
      await a.syncNow();
      final aPrefs = (await SharedPreferences.getInstance()).getString('savedPlaces.list');

      SharedPreferences.setMockInitialValues({});
      final b = await device('b', cloud);
      await b.syncNow();
      expect(b.syncError, isNull);
      expect(b.places.places.single.label, '自宅');
      expect(b.places.history.single.destination.name, saigon.name);
      await b.places.deletePlace('home');
      await b.syncNow();

      // 端末 A に戻る（SharedPreferences はプロセスで 1 つなので入れ直す）。
      SharedPreferences.setMockInitialValues({'savedPlaces.list': aPrefs!});
      final a2 = await device('a2', cloud);
      expect(a2.places.places, hasLength(1));
      await a2.syncNow();
      expect(a2.places.places, isEmpty);
      for (final c in [a, b, a2]) {
        c.dispose();
      }
    });
  });
}
