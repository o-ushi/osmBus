import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/deep_link.dart';
import 'package:osmbus/models/riding_session.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/models/route_search.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/state/app_settings.dart';
import 'package:osmbus/state/places_store.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  group('距離アラート', () {
    test('リングを内向きに越えたときだけ、遠い順に 1〜3 回鳴らす', () {
      final tracker = DistanceAlertTracker();
      const rings = [1000, 400, 100];
      expect(tracker.update(1500, rings), isNull);
      final first = tracker.update(900, rings)!;
      expect((first.meters, first.repeatCount, first.isNearest), (1000, 1, false));
      expect(tracker.update(950, rings), isNull, reason: '同じリングは二度鳴らさない');
      final second = tracker.update(350, rings)!;
      expect((second.meters, second.repeatCount), (400, 2));
      final third = tracker.update(80, rings)!;
      expect((third.meters, third.repeatCount, third.isNearest), (100, 3, true));
      expect(tracker.nearestReached, isTrue);
    });

    test('一度に複数越えたら一番近いリングだけ。始めからリング内ならそのリングを鳴らす', () {
      final tracker = DistanceAlertTracker();
      final fire = tracker.update(300, const [1000, 400, 100])!;
      expect(fire.meters, 400);
      expect(tracker.update(350, const [1000, 400, 100]), isNull, reason: '1000 も発火済み扱い');
    });
  });

  group('逆方向', () {
    final path = northward(21.0, 105.8, 6);
    final destination = path.last;
    RidingSession session(DateTime start) => RidingSession(
          ref: '35',
          alightStop: const RouteStop(id: 1, name: 'end', latitude: 21.045, longitude: 105.8),
          path: path,
          startedAt: start,
          boardingDistanceToDestination: Geo.distance(path.first, destination),
        );

    test('3 分経って進んでおらず、目的地から離れていれば検知', () {
      final start = DateTime(2026, 1, 1, 8);
      final away = GeoPoint(path.first.latitude - 4 * kmLat, 105.8);
      expect(
        WrongDirection.detect(session: session(start), position: away, destination: destination, now: start.add(const Duration(minutes: 4))),
        isTrue,
      );
      expect(
        WrongDirection.detect(session: session(start), position: away, destination: destination, now: start.add(const Duration(minutes: 2))),
        isFalse,
        reason: '乗って 3 分以内は見ない',
      );
      expect(
        WrongDirection.detect(session: session(start), position: path[3], destination: destination, now: start.add(const Duration(minutes: 4))),
        isFalse,
        reason: '路線を進んでいれば正しい向き',
      );
    });
  });

  group('コントローラ', () {
    late TripController controller;
    const origin = GeoPoint(21.0, 105.8);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      controller = TripController(prefs: prefs, sync: const UnsupportedCatalogSync(), requestsLocationOnLaunch: false);
    });

    tearDown(() => controller.dispose());

    test('乗車中、降車停へ近づくと距離アラートが順に積まれる', () async {
      final stops = northward(21.0, 105.8, 4);
      final route = route_(stops);
      controller.debugSetOrigin(origin);
      controller.startRidingRoute(route);
      expect(controller.riding?.alightStop.name, route.stops.last.name);
      controller.debugSetOrigin(GeoPoint(stops.last.latitude - 0.9 * kmLat, 105.8));
      expect(controller.pendingAlert, isA<DistanceRidingAlert>().having((a) => a.meters, 'meters', 1000));
      controller.dismissAlert();
      expect(controller.pendingAlert, isNull);
      controller.endRiding();
      expect(controller.riding, isNull);
    });

    test('目的地なしで路線図から乗ったら「あと」を出さない', () {
      controller.debugSetOrigin(origin);
      controller.startRidingRoute(route_(northward(21.0, 105.8, 4)));
      expect(controller.distanceLeftMeters, isNull);
    });

    test('「結果表示後はクリア」なら ⏎ のあとの数字で入力をやり直す', () async {
      await controller.settings.setKeypadInputMode(KeypadInputMode.clearBeforeNewInput);
      controller.appendDigit('3');
      controller.appendDigit('5');
      controller.submitInput();
      controller.appendDigit('7');
      expect(controller.input, '7');

      await controller.settings.setKeypadInputMode(KeypadInputMode.appendToExisting);
      controller.submitInput();
      controller.appendDigit('2');
      expect(controller.input, '72');
    });

    test('目的地を設定すると履歴に入り、ナビ中止で目的地が消える', () async {
      await controller.setDestination(const Destination(name: 'A', point: GeoPoint(21.01, 105.8)));
      await controller.setDestination(const Destination(name: 'B', point: GeoPoint(21.02, 105.8)));
      await controller.setDestination(const Destination(name: 'A', point: GeoPoint(21.01, 105.8)));
      expect(controller.places.history.map((e) => e.destination.name), ['A', 'B']);
      await controller.cancelNavigation();
      expect(controller.destination, isNull);
    });
  });

  group('プランと登録地', () {
    test('FREE は 3 件まで。FREE に戻ると切り詰める', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plan = PlanStore(prefs);
      final places = PlacesStore(prefs: prefs, plan: plan);
      SavedPlace place(int i) => SavedPlace(id: '$i', label: 'P$i', placeName: 'P$i', point: GeoPoint(21 + i / 100, 105));
      for (var i = 0; i < 3; i++) {
        expect(await places.addPlace(place(i)), isTrue);
      }
      expect(await places.addPlace(place(3)), isFalse);
      await plan.setPlan(AppPlan.paid);
      expect(await places.addPlace(place(3)), isTrue);
      for (var i = 0; i < 5; i++) {
        await places.addHistory(place(i).toDestination());
      }
      expect(places.history, hasLength(5));
      await plan.setPlan(AppPlan.free);
      await Future<void>.delayed(Duration.zero);
      expect(places.places, hasLength(3));
      expect(places.history.map((e) => e.destination.name), ['P4', 'P3', 'P2']);
    });
  });

  test('ディープリンク osmbus://destination', () {
    final d = OsmBusDeepLink.parseDestination(
      Uri.parse('osmbus://destination?name=Hoan%20Kiem&lat=21.0285&lng=105.8542&subtitle=Ha%20Noi'),
    )!;
    expect((d.name, d.subtitle, d.point.latitude, d.point.longitude), ('Hoan Kiem', 'Ha Noi', 21.0285, 105.8542));
    expect(OsmBusDeepLink.parseDestination(Uri.parse('osmbus://destination?name=x&lat=91&lng=0')), isNull);
    expect(OsmBusDeepLink.parseDestination(Uri.parse('https://destination?name=x&lat=1&lng=0')), isNull);
  });

  test('路線図の番号検索は系統違いも拾い、近い順に並べる。番号を含むだけの路線はその後', () {
    final near = route(id: 1, ref: '35A', stops: northward(21.0, 105.8, 3));
    final far = route(id: 2, ref: '35B', stops: northward(21.2, 105.8, 3));
    final other = route(id: 3, ref: '135', stops: northward(21.0, 105.8, 3));
    final found = RouteSearch.find([far, other, near], '35', near: const GeoPoint(21.0, 105.8));
    expect(found.map((r) => r.ref), ['35A', '35B', '135']);
  });

  test('路線図の番号検索は、入力した数字を含む路線をすべて挙げる（05 で E05 も）', () {
    final routes = [
      route(id: 1, ref: '05', stops: northward(21.0, 105.8, 3)),
      route(id: 2, ref: 'E05', stops: northward(21.0, 105.8, 3)),
      route(id: 3, ref: '105', stops: northward(21.0, 105.8, 3)),
      route(id: 4, ref: '50', stops: northward(21.0, 105.8, 3)),
    ];
    final found = RouteSearch.find(routes, '05');
    expect(found.map((r) => r.ref), containsAll(['05', 'E05', '105']));
    expect(found.map((r) => r.ref), isNot(contains('50')));
    expect(found.first.ref, '05');
  });
}

RouteRecord route_(List<GeoPoint> stops) => route(id: 77, ref: '77', stops: stops);
