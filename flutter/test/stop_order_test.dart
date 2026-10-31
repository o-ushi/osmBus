import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/official_stop_order.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/official_order_matcher.dart';
import 'package:osmbus/services/stop_order_source.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double lon = 105.78;
const double lat0 = 21.03;

/// 線上 [meters] の地点（北向き）。
GeoPoint at(double meters, {double eastMeters = 0}) =>
    GeoPoint(lat0 + meters / 110574, lon + eastMeters / 104000);

/// 北へ 0〜[length] m の直線の路線。停留所は (名前, 線上の位置) をメンバー順に。
RouteRecord osmRoute(int id, String ref, List<(String, double)> stops, {double length = 1500}) => RouteRecord(
      relationId: id,
      ref: ref,
      name: ref,
      stops: [
        for (final (i, (name, m)) in stops.indexed)
          RouteStop(id: id * 100 + i, name: name, latitude: at(m).latitude, longitude: at(m).longitude),
      ],
      polylineSegments: [
        [for (var m = 0.0; m <= length; m += 100) at(m)],
      ],
      hasGeometry: true,
    );

/// 公式の 1 方向。座標は OSM から東へ 30m ずらす。
OfficialRoute official(String ref, List<(String, double)> stops) => OfficialRoute(
      ref: ref,
      stops: [
        for (final (name, m) in stops)
          OfficialStop(name: name, latitude: at(m, eastMeters: 30).latitude, longitude: at(m, eastMeters: 30).longitude),
      ],
    );

String fileJson(String updated, List<OfficialRoute> routes) =>
    jsonEncode(OfficialStopOrderFile(updated: updated, routes: routes).toJson());

/// 公式: Cầu Giấy, Indochina Tower, PiCo, 79 Xuân Thủy, Đại học Quốc gia（300m 間隔）。
final officialE05 = official('E05', [
  ('Cầu Giấy', 0),
  ('INDOCHINA TOWER', 300),
  ('pico', 600),
  ('79 Xuan Thuy', 900),
  ('Đại học Quốc gia', 1200),
]);

/// OSM: PiCo が末尾。名前のない停留所が線の 450m（Indochina Tower と PiCo のあいだ）にある。
final brokenE05 = osmRoute(1, 'E05', [
  ('Cầu Giấy', 0),
  ('Indochina Tower', 300),
  ('79 Xuân Thủy', 900),
  ('Đại học Quốc gia', 1200),
  ('Nhà PiCo', 600),
  ('Trạm dừng', 450),
]);

List<String> names(List<RouteStop> stops) => [for (final s in stops) s.name];

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('stop_order_test');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => dir.deleteSync(recursive: true));

  StopOrderSource source(String bundled) =>
      StopOrderSource(bundled: () async => bundled, directory: () async => dir);

  Future<TripController> controllerWith(StopOrderSource stopOrder, List<RouteRecord> routes) async {
    final controller = TripController(
      prefs: await SharedPreferences.getInstance(),
      sync: const UnsupportedCatalogSync(),
      stopOrder: stopOrder,
      requestsLocationOnLaunch: false,
    );
    await stopOrder.load();
    controller.debugSetCatalog(CatalogSnapshot(routes: routes));
    return controller;
  }

  group('ステップ 1: 停留所順のファイル', () {
    test('同梱ファイルは読めて、1MB 以下', () {
      final file = File('assets/stop_order.json');
      expect(file.lengthSync(), lessThan(1024 * 1024));
      final parsed = OfficialStopOrderFile.fromJson(jsonDecode(file.readAsStringSync()));
      expect(parsed.updated, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('古い updated では差し替わらない', () async {
      final s = source(fileJson('2024-06-04', [officialE05]));
      await s.load();
      final result = await s.adopt(fileJson('2024-01-01', const []));
      expect(result, isA<StopOrderNotNewer>());
      expect(s.current.updated, '2024-06-04');
      expect(s.isBundled, isTrue);
    });

    test('新しい updated では差し替わり、その後の照合は新しいファイルを見る', () async {
      final s = source(fileJson('2024-06-04', const []));
      final controller = await controllerWith(s, [brokenE05]);
      addTearDown(controller.dispose);
      expect(controller.officialOrderStatus(1), isNull);

      final result = await s.adopt(fileJson('2025-01-01', [officialE05]));
      expect(result, isA<StopOrderUpdated>());
      expect(s.current.updated, '2025-01-01');
      expect(s.isBundled, isFalse);
      expect(controller.officialOrderStatus(1)?.state, OfficialOrderState.differs);

      // 保存したファイルは次の起動でも使う（同梱より新しいので）。
      final reloaded = source(fileJson('2024-06-04', const []));
      await reloaded.load();
      expect(reloaded.current.updated, '2025-01-01');
      expect(reloaded.isBundled, isFalse);
    });

    test('壊れた JSON、URL が空のときは今のファイルのまま', () async {
      final s = source(fileJson('2024-06-04', [officialE05]));
      await s.load();
      expect(await s.adopt('{"updated": "2030-01-01", "routes": [{'), isA<StopOrderUpdateFailed>());
      expect(await s.adopt('{"updated": "June 2030", "routes": []}'), isA<StopOrderUpdateFailed>());
      expect(await s.update(), isA<StopOrderUpdateFailed>(), reason: 'updateUrl は空');
      expect(StopOrderSource.updateUrl, isEmpty);
      expect(s.current.updated, '2024-06-04');
      expect(s.current.routes, hasLength(1));
    });
  });

  group('ステップ 2: 公式の順との対応', () {
    test('PiCo が Indochina Tower と 79 Xuân Thủy のあいだに来て、対応しない停留所も線の順で残る', () {
      final match = OfficialOrderMatcher.match(brokenE05, [officialE05])!;
      final ordered = OfficialOrderMatcher.reorder(brokenE05, match.orderedIds)!;
      expect(names(ordered), [
        'Cầu Giấy',
        'Indochina Tower',
        'Trạm dừng',
        'Nhà PiCo',
        '79 Xuân Thủy',
        'Đại học Quốc gia',
      ]);
      expect(match.pairCount, 5);
    });

    test('公式側の名前が空なら座標だけで対応させる', () {
      final nameless = OfficialRoute(ref: 'E05', stops: [
        for (final s in officialE05.stops) OfficialStop(name: '', latitude: s.latitude, longitude: s.longitude),
      ]);
      final match = OfficialOrderMatcher.match(brokenE05, [nameless])!;
      expect(names(OfficialOrderMatcher.reorder(brokenE05, match.orderedIds)!)[3], 'Nhà PiCo');
    });

    test('系統は ref で対応させる（E05 と 05 は別）', () {
      final other = official('05', [for (final s in officialE05.stops) (s.name, 0)]);
      expect(OfficialOrderMatcher.match(brokenE05, [other]), isNull);
    });

    test('対応が 3 件以下の路線は変えない', () {
      final few = official('E05', [('Cầu Giấy', 0), ('Indochina Tower', 300), ('PiCo', 600)]);
      expect(OfficialOrderMatcher.match(brokenE05, [few]), isNull);
    });

    test('対応が少ない方の半分未満の路線は変えない', () {
      final osm = osmRoute(2, '32', [for (var i = 0; i < 10; i++) ('Stop $i', i * 150.0)]);
      // 4 件だけ同じ名前で、ほかは別の名前。
      final half = official('32', [
        for (var i = 0; i < 10; i++) (i < 4 ? 'Stop $i' : 'Khác $i', i * 150.0),
      ]);
      expect(OfficialOrderMatcher.match(osm, [half]), isNull);
    });

    test('座標が 150m より離れた同名の停留所は組にしない', () {
      final far = OfficialRoute(ref: 'E05', stops: [
        for (final s in officialE05.stops) OfficialStop(name: s.name, latitude: s.latitude, longitude: s.longitude + 0.002),
      ]);
      expect(OfficialOrderMatcher.match(brokenE05, [far]), isNull);
    });

    test('組が線の上で 1km 以上戻るときは変えない', () {
      final osm = osmRoute(3, '39', [for (var i = 0; i < 5; i++) ('S$i', i * 700.0)], length: 2800);
      final reversed = official('39', [for (var i = 4; i >= 0; i--) ('S$i', i * 700.0)]);
      expect(OfficialOrderMatcher.match(osm, [reversed]), isNull);
    });

    test('往復どちらも同程度に重なるときは対応しない', () {
      final copy = OfficialRoute(ref: 'E05', from: 'B', to: 'A', stops: officialE05.stops);
      expect(OfficialOrderMatcher.match(brokenE05, [officialE05, copy]), isNull);
    });

    test('適用した順は ID で覚え、ID が路線から消えたら記憶を捨てて OSM の順に戻る', () async {
      final controller = await controllerWith(source(fileJson('2024-06-04', [officialE05])), [brokenE05]);
      addTearDown(controller.dispose);
      controller.applyOfficialOrder(1);
      expect(controller.isOfficialOrderApplied(1), isTrue);
      expect(names(controller.visibleCatalogForTest(1)), contains('Nhà PiCo'));
      expect(names(controller.visibleCatalogForTest(1))[3], 'Nhà PiCo');

      // 路線データの更新で停留所 ID が 1 つ変わった。
      final changed = brokenE05.copyWith(stops: [
        ...brokenE05.stops.take(5),
        RouteStop(id: 999, name: 'Trạm dừng', latitude: at(450).latitude, longitude: at(450).longitude),
      ]);
      controller.debugSetCatalog(CatalogSnapshot(routes: [changed]));
      expect(controller.isOfficialOrderApplied(1), isFalse);
      expect(names(controller.visibleCatalogForTest(1)), names(changed.stops));
      expect((await SharedPreferences.getInstance()).getString('stopOrder.applied'), isNull);
    });
  });

  group('ステップ 3: 路線図のヒント', () {
    test('違いがある路線では、降車停の前後の文が作れる', () async {
      final controller = await controllerWith(source(fileJson('2024-06-04', [officialE05])), [brokenE05]);
      addTearDown(controller.dispose);
      final status = controller.officialOrderStatus(1)!;
      expect(status.state, OfficialOrderState.differs);
      final xuanThuy = brokenE05.stops.firstWhere((s) => s.name == '79 Xuân Thủy');
      final lines = OfficialOrderMatcher.hint(
        current: status.osmOrder,
        official: status.officialOrder,
        anchorId: xuanThuy.id,
      );
      expect(lines.first.anchor, '79 Xuân Thủy');
      expect(lines.first.before, isTrue);
      expect(lines.first.current, 'Indochina Tower');
      expect(lines.first.official, 'Nhà PiCo');

      // 降車停が無いときは、最初に順が違う箇所の手前だけ。
      final first = OfficialOrderMatcher.hint(current: status.osmOrder, official: status.officialOrder);
      expect(first, hasLength(1));
      expect(first.single.before, isTrue);

      controller.applyOfficialOrder(1);
      expect(controller.officialOrderStatus(1)?.state, OfficialOrderState.applied);
      controller.revertOfficialOrder(1);
      expect(controller.isOfficialOrderApplied(1), isFalse);
      expect(names(controller.visibleCatalogForTest(1)), names(brokenE05.stops));
    });

    test('一致している路線ではヒントが無い', () async {
      final ordered = osmRoute(4, 'E05', [for (final s in officialE05.stops) (s.name, 0)]).copyWith(
        stops: [
          for (final (i, s) in officialE05.stops.indexed)
            RouteStop(id: 400 + i, name: s.name, latitude: at(i * 300.0).latitude, longitude: at(i * 300.0).longitude),
        ],
      );
      final controller = await controllerWith(source(fileJson('2024-06-04', [officialE05])), [ordered]);
      addTearDown(controller.dispose);
      expect(OfficialOrderMatcher.match(ordered, [officialE05]), isNotNull);
      expect(controller.officialOrderStatus(4), isNull);
    });
  });

  group('ステップ 4: 全路線の点検', () {
    test('直せる路線だけ適用し、自信がない路線は元のまま', () async {
      final unsureRoute = osmRoute(5, '33', [('A', 0), ('B', 300), ('C', 600), ('D', 900)]);
      final unsureOfficial = official('33', [('A', 0), ('C', 600), ('X', 300)]);
      final controller = await controllerWith(
        source(fileJson('2024-06-04', [officialE05, unsureOfficial])),
        [brokenE05, unsureRoute],
      );
      addTearDown(controller.dispose);

      final inspection = controller.inspectStopOrder();
      expect([for (final (r, _) in inspection.fixable) r.relationId], [1]);
      expect([for (final r in inspection.unsure) r.ref], ['33']);
      expect(controller.isOfficialOrderApplied(1), isFalse, reason: '点検だけでは適用しない');

      controller.applyInspection(inspection);
      expect(controller.isOfficialOrderApplied(1), isTrue);
      expect(controller.isOfficialOrderApplied(5), isFalse);
      expect(names(controller.visibleCatalogForTest(5)), ['A', 'B', 'C', 'D']);
      expect(controller.officialOrderStatus(1)?.state, OfficialOrderState.applied);
      // 適用済みの路線は、次の点検の数に入らない。
      expect(controller.inspectStopOrder().fixable, isEmpty);
    });
  });
}

extension on TripController {
  /// 同意に関係なく、今の並び（公式の順を被せたもの）。
  List<RouteStop> visibleCatalogForTest(int relationId) =>
      debugCatalog.routes.firstWhere((r) => r.relationId == relationId).stops;
}
