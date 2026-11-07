import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/local_itinerary.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/services/local_planner.dart';
import 'package:osmbus/state/trip_controller.dart';

import 'fixtures.dart';
import 'nav_origin_alight_color_test.dart' show east, line, lon, makeController, settle;

void main() {
  group('番号表の ↻ は、出発地が現在地ならその時点の現在地で引き直す', () {
    final first = east(line.stops[0].point, 60);
    final second = east(line.stops[1].point, 60);
    final goal = east(line.stops[4].point, 60);

    test('ナビ中でも、↻ を押した時点の GPS が出発地になる', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetOrigin(first);
      await controller.setDestination(Destination(name: 'goal', point: goal));
      await settle(controller);
      controller.debugSetOrigin(second);
      expect(controller.origin, first, reason: 'GPS だけでは動かさない');

      await controller.reload();
      await settle(controller);
      expect(controller.origin, second);
      expect(controller.itineraries.single.firstLeg.boardStop.id, line.stops[1].id);
    });

    test('手動の出発地のときは変えない', () async {
      final controller = await makeController();
      addTearDown(controller.dispose);
      controller.debugSetOrigin(first);
      await controller.setDestination(Destination(name: 'goal', point: goal));
      final picked = line.stops[2].point;
      controller.setManualOrigin(Destination(name: 'picked', point: picked));
      controller.debugSetOrigin(second);
      await controller.reload();
      expect(controller.origin, picked);
      controller.clearManualOrigin();
      expect(controller.origin, first, reason: '固定した出発地もそのまま');
      await settle(controller);
    });
  });

  group('乗換地点を ＋／− でずらすと、次のレグの乗車停留所も合わせる', () {
    // A: 北へ 4 停留所。B: A の各停留所の 30m 東を北へ走り、さらに先の停留所まで。
    final a = route(id: 9, ref: '09', stops: northward(21.0, lon, 4));
    final bStops = [for (final s in a.stops) east(s.point, 30), GeoPoint(21.0 + 5 * kmLat, lon + 0.0003)];
    final b = route(id: 10, ref: '10', stops: bStops);

    LocalItinerary trip() => LocalItinerary(
          legs: [LocalPlanner.legOf(a, 0, 2), LocalPlanner.legOf(b, 2, 4)],
          walkMeters: 30,
          bearing: 0,
        );

    Future<TripController> riding() async {
      final controller = await makeController();
      controller.debugSetCatalog(CatalogSnapshot(routes: [a, b]));
      controller.debugSetOrigin(a.stops[0].point);
      controller.toggleRidingLeg(trip(), 0);
      return controller;
    }

    test('− で 1 つ手前に降りると、乗換先もその停留所の近くから乗る', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      controller.shiftRidingAlight(-1);
      expect(controller.riding!.alightStop.id, a.stops[1].id);
      final shown = controller.ridingView(trip());
      expect(shown.legs[1].boardStop.id, b.stops[1].id);
      expect(shown.legs[1].alightStop.id, b.stops[4].id, reason: '乗換先の降車はそのまま');
      expect(shown.legs[1].path.first, b.stops[1].point);
    });

    test('＋ で先に降りると乗換先の乗車停留所も先へ。乗り換えるとそこから乗ったことになる', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      controller.shiftRidingAlight(1);
      expect(controller.ridingView(trip()).legs[1].boardStop.id, b.stops[3].id);

      controller.debugSetOrigin(b.stops[3].point);
      controller.toggleRidingLeg(trip(), 1);
      expect(controller.riding!.ref, '10');
      expect(controller.riding!.boardStopId, b.stops[3].id);
      expect(controller.distanceLeftMeters, closeTo(Geo.distance(b.stops[3].point, b.stops[4].point), 1));
    });
  });

  group('路線の線をたどる', () {
    test('環状の路線で、終点が始点と同じ場所でも最後の区間は線に沿う', () {
      // 北へ 1km → 東へ 1km → 南へ 1km → 西へ 1km で始点に戻る線。
      const lat0 = 21.0;
      const dLon = 0.0096;
      final corners = [
        const GeoPoint(lat0, lon),
        const GeoPoint(lat0 + kmLat, lon),
        const GeoPoint(lat0 + kmLat, lon + dLon),
        const GeoPoint(lat0, lon + dLon),
        const GeoPoint(lat0, lon),
      ];
      final polyline = <GeoPoint>[];
      for (var i = 0; i + 1 < corners.length; i++) {
        for (var s = 0; s < 10; s++) {
          final t = s / 10;
          polyline.add(GeoPoint(
            corners[i].latitude + (corners[i + 1].latitude - corners[i].latitude) * t,
            corners[i].longitude + (corners[i + 1].longitude - corners[i].longitude) * t,
          ));
        }
      }
      polyline.add(corners.last);
      final stops = [corners[0], corners[1], corners[2], corners[3], const GeoPoint(lat0, lon + 0.0004)];
      final loop = route(id: 11, ref: '11', stops: stops).copyWith(polylineSegments: [polyline]);

      final last = LocalPlanner.legOf(loop, 3, 4);
      expect(last.path.length, greaterThan(3), reason: '始点側の頂点に吸われて直線にならない');
      expect(last.rideMeters, closeTo(Geo.distance(corners[3], stops[4]), 30));

      final first = LocalPlanner.legOf(loop, 0, 1);
      expect(first.rideMeters, closeTo(1000, 30), reason: '始点は線の始まり側');
    });

    test('行って U ターンして戻る線で、折り返しを通る区間は折り返しをたどる', () {
      // 経度 lon を北へ 1km、東へ 60m 回って、経度 lon+60m を南へ戻る。
      final out = [for (var i = 0; i <= 10; i++) GeoPoint(21.0 + i * kmLat / 10, lon)];
      final turn = east(out.last, 60);
      final back = [for (var i = 10; i >= 0; i--) east(GeoPoint(21.0 + i * kmLat / 10, lon), 60)];
      final polyline = [...out, ...back];
      final stops = [out[0], out[9], back[4]];
      final r = route(id: 12, ref: '12', stops: stops).copyWith(polylineSegments: [polyline]);

      final leg = LocalPlanner.legOf(r, 1, 2);
      expect(leg.path.any((p) => Geo.distance(p, turn) < 5), isTrue);
      expect(leg.rideMeters, closeTo(100 + 60 + 400, 10), reason: "直線（約 300m）ではなく 北 100m → 東 60m → 南 400m");
    });
  });
}
