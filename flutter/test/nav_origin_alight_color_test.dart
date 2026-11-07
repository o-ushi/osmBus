import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/local_itinerary.dart';
import 'package:osmbus/models/riding_session.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/services/local_planner.dart';
import 'package:osmbus/services/stop_order_repair.dart';
import 'package:osmbus/state/app_settings.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:osmbus/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const double lon = 105.8;

/// 北へ 1km 間隔の 5 停留所の路線。
final RouteRecord line = route(id: 7, ref: '07', stops: northward(21.0, lon, 5));

GeoPoint east(GeoPoint p, double meters) => GeoPoint(p.latitude, p.longitude + meters / 104000);

Future<TripController> makeController({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'privacy.thirdPartyConsent.version': 1, ...prefs});
  final controller = TripController(
    prefs: await SharedPreferences.getInstance(),
    sync: const UnsupportedCatalogSync(),
    requestsLocationOnLaunch: false,
  );
  controller.debugSetCatalog(CatalogSnapshot(routes: [line]));
  return controller;
}

/// 別 isolate の計画が終わるまで待つ。
Future<void> settle(TripController controller) async {
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (controller.tableState != TableState.calculating) return;
  }
}

void main() {
  group('ステップ 1: ナビ中は出発地を固定する', () {
    final first = east(line.stops[0].point, 60);
    final second = east(line.stops[1].point, 60);
    final goal = east(line.stops[4].point, 60);

    test('目的地がある状態で 2 回位置が届いても、出発地と旅程は 1 回目のまま', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      await controller.setDestination(Destination(name: 'goal', point: goal));
      controller.debugSetOrigin(first);
      await settle(controller);
      expect(controller.origin, first);
      expect(controller.itineraries.single.firstLeg.boardStop.id, line.stops[0].id);

      controller.debugSetOrigin(second);
      await settle(controller);
      expect(controller.origin, first);
      expect(controller.gps, second, reason: '青い丸はライブの GPS');
      expect(controller.originPin, first);
      expect(controller.itineraries.single.firstLeg.boardStop.id, line.stops[0].id);
    });

    test('↻（次の 1 点を採用）のあとは、2 回目の位置で引き直し、その後は再び固定する', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetOrigin(first);
      await controller.setDestination(Destination(name: 'goal', point: goal));
      await settle(controller);
      expect(controller.origin, first);

      controller.adoptNextFixAsOrigin();
      controller.debugSetOrigin(second);
      await settle(controller);
      expect(controller.origin, second);
      expect(controller.itineraries.single.firstLeg.boardStop.id, line.stops[1].id);

      controller.debugSetOrigin(first);
      expect(controller.origin, second, reason: '↻ は 1 点だけ採用する');
    });

    test('目的地が無いときは、後の位置が出発地になる', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetOrigin(first);
      controller.debugSetOrigin(second);
      expect(controller.origin, second);
    });

    test('手動の出発地を消すと、ライブの GPS ではなく固定した出発地に戻る。ナビ中止で固定を解く', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetOrigin(first);
      await controller.setDestination(Destination(name: 'goal', point: goal));
      controller.setManualOrigin(Destination(name: 'picked', point: line.stops[2].point));
      expect(controller.origin, line.stops[2].point);
      controller.debugSetOrigin(second);
      controller.clearManualOrigin();
      expect(controller.origin, first);

      await controller.cancelNavigation();
      expect(controller.origin, second);
    });

    test('固定した出発地は保存され、目的地と一緒に戻る', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetOrigin(first);
      await controller.setDestination(Destination(name: 'goal', point: goal));
      final prefs = await SharedPreferences.getInstance();
      final saved = GeoPoint.fromJson(jsonDecode(prefs.getString('navigation.routeOrigin')!) as Map<String, dynamic>);
      expect(saved, first);
      await controller.cancelNavigation();
      expect(prefs.getString('navigation.routeOrigin'), isNull);
    });
  });

  group('ステップ 2: 降車停を ＋／− でずらす', () {
    final four = route(id: 9, ref: '09', stops: northward(21.0, lon, 4));

    Future<TripController> riding() async {
      final controller = await makeController();
      controller.debugSetCatalog(CatalogSnapshot(routes: [four]));
      controller.debugSetOrigin(four.stops[0].point);
      final leg = LocalPlanner.legOf(four, 0, 2);
      controller.toggleRidingLeg(LocalItinerary(legs: [leg], walkMeters: 0, bearing: 0), 0);
      return controller;
    }

    test('初期の降車が 3 番目なら ＋で 4 番目、−で 2 番目、乗車停留所より前には行かない', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      expect(controller.riding!.alightStop.id, four.stops[2].id);

      controller.shiftRidingAlight(1);
      expect(controller.riding!.alightStop.id, four.stops[3].id);
      expect(controller.alightChoice!.canNext, isFalse);
      controller.shiftRidingAlight(1);
      expect(controller.riding!.alightStop.id, four.stops[3].id, reason: '終点より先には行かない');

      controller.shiftRidingAlight(-1);
      controller.shiftRidingAlight(-1);
      expect(controller.riding!.alightStop.id, four.stops[1].id);
      expect(controller.alightChoice!.canPrevious, isFalse);
      controller.shiftRidingAlight(-1);
      expect(controller.riding!.alightStop.id, four.stops[1].id, reason: '乗車停留所より前には行かない');
    });

    test('変えたあとの残り距離と乗車中の線の終わりはその停留所', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      controller.shiftRidingAlight(1);
      final target = four.stops[3].point;
      expect(controller.distanceLeftMeters, closeTo(Geo.distance(four.stops[0].point, target), 1));
      expect(controller.riding!.path.last, target);
      final shown = controller.ridingView(LocalItinerary(legs: [LocalPlanner.legOf(four, 0, 2)], walkMeters: 0, bearing: 0));
      expect(shown.legs.single.alightStop.id, four.stops[3].id);
    });

    test('乗車の保存に含まれ、復元後も効く', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      controller.shiftRidingAlight(-1);
      final restored = RidingSession.fromJson(
        jsonDecode(jsonEncode(controller.riding!.toJson())) as Map<String, dynamic>,
      );
      expect(restored.alightStop.id, four.stops[1].id);
      expect(restored.alightAdjusted, isTrue);
      expect(restored.boardStopId, four.stops[0].id);
    });

    test('路線図から乗ったとき（降車は終点）も同じ列で − できる', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetCatalog(CatalogSnapshot(routes: [four]));
      controller.debugSetOrigin(four.stops[1].point);
      controller.startRidingRoute(four);
      expect(controller.distanceLeftMeters, isNull);
      expect(controller.alightChoice!.canNext, isFalse);
      controller.shiftRidingAlight(-1);
      expect(controller.riding!.alightStop.id, four.stops[2].id);
      expect(controller.alightChoice!.canPrevious, isFalse, reason: '乗ったのは 2 番目の停留所');
      expect(controller.distanceLeftMeters, closeTo(Geo.distance(four.stops[1].point, four.stops[2].point), 1));
    });
  });

  group('ステップ 3: 距離の色は距離アラートの段', () {
    Color band(double meters, [List<int> slots = DistanceAlertSlot.defaultMeters]) =>
        DistanceColorBand.colors(meters, slots).$1;

    test('初期値（1000 / 400 / 100）', () {
      expect(band(3000), Colors.blue);
      expect(band(2999), Colors.green);
      expect(band(1000), Colors.green);
      expect(band(999), Colors.orange);
      expect(band(400), Colors.orange);
      expect(band(399), Colors.yellow);
      expect(band(100), Colors.yellow);
      expect(band(99), Colors.red);
    });

    test('距離アラート 1 を 2000m にすると境目も 2000m', () {
      expect(band(1999, [2000, 400, 100]), Colors.orange);
      expect(band(2000, [2000, 400, 100]), Colors.green);
    });

    test('文字色は黄・橙が黒、ほかは白', () {
      for (final (meters, text) in [(3000.0, Colors.white), (2000.0, Colors.white), (500.0, Colors.black), (200.0, Colors.black), (50.0, Colors.white)]) {
        expect(DistanceColorBand.colors(meters, DistanceAlertSlot.defaultMeters).$2, text);
      }
    });
  });

  group('ステップ 4: 停留所の並びが線と逆行している路線だけ、提案として並べ替える', () {
    final a = const GeoPoint(21.0, lon);
    final b = GeoPoint(21.0 + kmLat, lon);
    final c = GeoPoint(21.0 + 2 * kmLat, lon);
    final d = GeoPoint(21.0 + 3 * kmLat, lon);

    RouteRecord record(List<GeoPoint> stops, List<List<GeoPoint>> segments) =>
        route(id: 5, ref: 'E05', stops: stops).copyWith(polylineSegments: segments);

    List<GeoPoint> points(RouteRecord r) => [for (final s in r.stops) s.point];

    test('線が A→B→C→D、停留所が A, D, B なら A, B, D に直し、B から D まで直通で出る', () {
      final broken = record([a, d, b], [[a, b, c, d]]);
      final origin = east(b, 50);
      final goal = east(d, 100);
      expect(LocalPlanner.plan([broken], origin, goal), isEmpty, reason: '直す前は B が最後で降りられない');

      final fixed = StopOrderRepair.repair(broken);
      expect(points(fixed), [a, b, d]);
      final plan = LocalPlanner.plan([fixed], origin, goal);
      expect(plan, hasLength(1));
      expect(plan.single.legs, hasLength(1));
      expect(plan.single.firstLeg.boardStop.point, b);
      expect(plan.single.firstLeg.alightStop.point, d);
    });

    test('線の順になっている路線は、停留所の順も中身も変えない', () {
      final ok = record([a, b, d], [[a, b, c, d]]);
      expect(identical(StopOrderRepair.repair(ok), ok), isTrue);
    });

    test('戻りが 1km 未満なら並べ替えない', () {
      final slightly = GeoPoint(b.latitude - 0.005, lon); // B の約 550m 手前
      final r = record([a, b, slightly, d], [[a, b, c, d]]);
      expect(identical(StopOrderRepair.repair(r), r), isTrue);
    });

    test('線から 120m より離れた停留所は元の位置のまま', () {
      final off = east(c, 400);
      final fixed = StopOrderRepair.repair(record([a, d, off, b], [[a, b, c, d]]));
      expect(points(fixed), [a, b, off, d]);
    });

    test('線が切れていても、切れたセグメントをメンバー順に繋いで測る', () {
      final fixed = StopOrderRepair.repair(record([a, d, b], [[a, b], [c, d]]));
      expect(points(fixed), [a, b, d]);
    });

    test('線が同じ場所を 2 度通っても、各停留所を一番近い位置で並べる', () {
      final loop = StopOrderRepair.repair(record([a, d, b], [[a, b, c, d, c, b, a]]));
      expect(points(loop), [a, b, d]);
    });

    test('戻りが 1km 以上ある路線だけ並べ替える条件は、線が 2 度通る路線でも同じ', () {
      final loop = record([a, b, d], [[a, b, c, d, c, b, a]]);
      expect(identical(StopOrderRepair.repair(loop), loop), isTrue);
    });

    test('E05 復路（13534192）: Indochina Tower が線に二度落ちても PiCo がそのあいだに入る', () {
      // 線と停留所の座標を縮めたフィクスチャ。位置は (東へ m, 北へ m)。
      // 線は Indochina Tower の前で小さく回り、もう一度その前を通る（Indochina Tower は線の近くに
      // 1000m 離れて二度落ちる）。
      const origin = GeoPoint(21.0048, 105.7545);
      GeoPoint m(double eastM, double northM) =>
          GeoPoint(origin.latitude + northM / 110574, origin.longitude + eastM / 104000);
      final line = [m(0, 0), m(2900, 0), m(3100, 0), m(3100, 300), m(2900, 300), m(2900, 0), m(8000, 0)];
      const indochina = 'Tòa nhà Indochina Tower - Đối diện ĐHQG Hà Nội';
      const pico = 'Siêu thị điện máy PiCo - 173 Xuân Thủy';
      final members = [
        ('Điểm đỗ xe buýt Smart City', m(0, -20)),
        ('Đại lộ Thăng Long', m(1500, 20)),
        (indochina, m(3000, -20)),
        ('79 Xuân Thủy', m(3600, -20)),
        ('Cầu Giấy', m(5000, 20)),
        // OSM のメンバーでは末尾近くにある。
        (pico, m(3300, -20)),
        ('Long Biên', m(8000, 20)),
      ];
      final e05 = RouteRecord(
        relationId: 13534192,
        ref: 'E05',
        name: 'E05: Smart City → Long Biên',
        stops: [
          for (final (i, (name, p)) in members.indexed)
            RouteStop(id: i + 1, name: name, latitude: p.latitude, longitude: p.longitude),
        ],
        polylineSegments: [line],
        hasGeometry: true,
      );
      final fixed = StopOrderRepair.repair(e05);
      expect([for (final s in fixed.stops) s.name], [
        'Điểm đỗ xe buýt Smart City',
        'Đại lộ Thăng Long',
        indochina,
        pico,
        '79 Xuân Thủy',
        'Cầu Giấy',
        'Long Biên',
      ]);
    });

    test('目的地が線から 550m より遠ければ、直しても通さない', () {
      final fixed = StopOrderRepair.repair(record([a, d, b], [[a, b, c, d]]));
      expect(LocalPlanner.plan([fixed], east(b, 50), east(d, 800)), isEmpty);
    });

    test('読み込んだカタログには効かせない。線と逆行していても OSM のメンバー順のまま', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetCatalog(CatalogSnapshot(routes: [record([a, d, b], [[a, b, c, d]])]));
      expect(points(controller.visibleCatalog.routes.single), [a, d, b]);
    });
  });
}
