import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/bus_matrix.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/services/local_planner.dart';

import 'fixtures.dart';

void main() {
  const lon = 105.8;
  final stops = northward(21.0, lon, 4);
  final origin = GeoPoint(21.0 - hundredMetersLat, lon);
  final destination = GeoPoint(stops.last.latitude + hundredMetersLat, lon);

  group('geo', () {
    test('Haversine と方位', () {
      expect(Geo.distance(origin, stops.first), closeTo(100, 1));
      expect(Geo.compassIndex(Geo.bearing(stops.first, stops.last)), 0);
      expect(Geo.compassIndex(Geo.bearing(stops.last, stops.first)), 4);
      expect(Geo.polylineLength([stops.first]), 0);
    });
  });

  group('直通', () {
    test('出発地と目的地が両端の 100m なら乗換 0 の旅程が 1 つ', () {
      final result = LocalPlanner.plan([route(id: 1, ref: '35', stops: stops)], origin, destination);
      expect(result, hasLength(1));
      final itinerary = result.single;
      expect(itinerary.transferCount, 0);
      expect(itinerary.firstLeg.boardIndex, 0);
      expect(itinerary.firstLeg.alightIndex, 3);
      expect(itinerary.walkMeters, closeTo(200, 2));
      expect(itinerary.rideMeters, closeTo(3000, 10));
      expect(itinerary.compassIndex, 0);
    });

    test('停留所順が目的地→出発地の向きだけの路線は出ない', () {
      final reversed = route(id: 2, ref: '35', stops: stops.reversed.toList());
      expect(LocalPlanner.plan([reversed], origin, destination), isEmpty);
      final both = LocalPlanner.plan(
        [route(id: 1, ref: '35', stops: stops), reversed],
        origin,
        destination,
      );
      expect(both, hasLength(1));
      expect(both.single.firstLeg.relationId, 1);
    });

    test('形状が無ければ両停留所間の直線距離', () {
      final result = LocalPlanner.plan(
        [route(id: 1, ref: '35', stops: stops, withPolyline: false)],
        origin,
        destination,
      );
      expect(result.single.rideMeters, closeTo(Geo.distance(stops.first, stops.last), 0.01));
    });

    test('形状が未取得の路線は対象外', () {
      final record = route(id: 1, ref: '35', stops: stops).copyWith(hasGeometry: false);
      expect(LocalPlanner.plan([record], origin, destination), isEmpty);
    });
  });

  group('乗換', () {
    test('A が届かず、T から 100m の B が目的地へ届けば乗換 1', () {
      // A: 北へ 3 停留所。最後が T。
      final a = route(id: 10, ref: '7', stops: northward(21.0, lon, 3));
      final t = a.stops.last.point;
      // B: T の 100m 北から東へ 1km 間隔。
      final bStops = [
        for (var i = 0; i < 4; i++) GeoPoint(t.latitude + hundredMetersLat, lon + 0.01 + i * 0.0096),
      ]..[0] = GeoPoint(t.latitude + hundredMetersLat, lon);
      final b = route(id: 20, ref: '99', stops: bStops);
      final dest = GeoPoint(bStops.last.latitude + hundredMetersLat, bStops.last.longitude);

      final result = LocalPlanner.plan([a, b], origin, dest);
      expect(result, hasLength(1));
      final itinerary = result.single;
      expect(itinerary.transferCount, 1);
      expect(itinerary.legs.map((l) => l.ref), ['7', '99']);
      expect(itinerary.firstLeg.alightStop.name, '7-stop2');
      expect(itinerary.walkMeters, closeTo(300, 3));

      final rows = BusMatrix.byDirection(result);
      expect(rows, hasLength(1));
      expect(rows.single.cells[0], isEmpty);
      expect(rows.single.cells[1].single.token, '7');
      expect(rows.single.cells[2], isEmpty);
    });

    test('直通で着く並行路線は乗換の列に出ない', () {
      final parallel = [for (final s in stops) GeoPoint(s.latitude, s.longitude + 0.0008)];
      final feeder = route(id: 3, ref: '7', stops: northward(21.0, lon - 0.002, 2));
      final result = LocalPlanner.plan(
        [route(id: 1, ref: '35A', stops: stops), route(id: 2, ref: '35B', stops: parallel), feeder],
        origin,
        destination,
      );
      final byRef = {for (final i in result) '${i.firstLeg.ref}/${i.column}'};
      expect(byRef, containsAll(['35A/0', '35B/0']));
      expect(byRef, isNot(contains('35A/1')));
      expect(byRef, isNot(contains('35B/1')));
      expect(byRef, isNot(contains('35A/2')));
      // 出発地から 35A/35B に直接乗れるので、7 に乗ってから 35A/35B へ乗り換える案も出さない。
      expect(byRef, isNot(contains('7/1')));
    });

    test('乗換 2 回', () {
      final a = route(id: 10, ref: '7', stops: northward(21.0, lon, 3));
      final t1 = a.stops.last.point;
      final bStops = [for (var i = 0; i < 3; i++) GeoPoint(t1.latitude, lon + 0.0005 + i * 0.0096)];
      final b = route(id: 20, ref: '8', stops: bStops);
      final t2 = bStops.last;
      final cStops = [for (var i = 0; i < 3; i++) GeoPoint(t2.latitude + 0.0005 + i * kmLat, t2.longitude)];
      final c = route(id: 30, ref: '9', stops: cStops);
      final dest = GeoPoint(cStops.last.latitude + hundredMetersLat, cStops.last.longitude);

      final result = LocalPlanner.plan([a, b, c], origin, dest);
      final two = result.where((i) => i.transferCount == 2).toList();
      expect(two, hasLength(1));
      expect(two.single.legs.map((l) => l.ref), ['7', '8', '9']);
      expect(BusMatrix.byDirection(result).single.cells[2].single.token, '7');
    });
  });

  group('路線の形と寄り道', () {
    test('way の順番が崩れた路線でも、端から端の直線にならず停留所に沿う', () {
      // 線を後ろ半分・前半分の順に並べた（Overpass の way 順が崩れたとき）。
      final line = northward(21.0, lon, 4);
      final broken = route(id: 1, ref: '35', stops: line).copyWith(polylineSegments: [
        [line[2], line[3]],
        [line[0], line[1], line[2]],
      ]);
      final leg = LocalPlanner.plan([broken], origin, destination).single.firstLeg;
      expect(leg.rideMeters, closeTo(Geo.polylineLength(line), 5));
      expect(leg.path.length, greaterThanOrEqualTo(4), reason: '2 点の直線ではない');
    });

    test('直線距離 × 2 + 2km を超える寄り道の案は出さない', () {
      // 東へ 4km 行って戻ってくる路線。
      final detour = [
        stops.first,
        GeoPoint(21.0, lon + 0.04),
        GeoPoint(21.0 + kmLat, lon + 0.04),
        GeoPoint(stops.last.latitude, lon + 0.04),
        stops.last,
      ];
      final result = LocalPlanner.plan([route(id: 1, ref: '99', stops: detour)], origin, destination);
      expect(result, isEmpty);
    });

    test('乗換は徒歩だけでなく乗車を含めた時間で選ぶ', () {
      // A に乗って、近い乗換（遠回りの B）と少し歩く乗換（まっすぐの C）がある。
      final a = route(id: 10, ref: '7', stops: northward(21.0, lon, 3));
      final t = a.stops.last.point;
      final dest = GeoPoint(t.latitude + 3 * kmLat, lon + 0.02);
      final slow = route(id: 20, ref: '8', stops: [
        GeoPoint(t.latitude, t.longitude + 0.0002),
        GeoPoint(t.latitude, lon + 0.05),
        GeoPoint(dest.latitude, lon + 0.05),
        GeoPoint(dest.latitude, dest.longitude + 0.001),
      ]);
      final fast = route(id: 30, ref: '9', stops: [
        GeoPoint(t.latitude, t.longitude + 0.002),
        GeoPoint(dest.latitude - hundredMetersLat, dest.longitude),
      ]);
      final result = LocalPlanner.plan([a, slow, fast], origin, dest);
      final transfer = result.where((i) => i.firstLeg.ref == '7').single;
      expect(transfer.legs.last.ref, '9');
    });

    test('乗換 2 回の案は、乗換 1 回以下より 5 分以上速いときだけ出す', () {
      final a = route(id: 10, ref: '7', stops: northward(21.0, lon, 3));
      final t1 = a.stops.last.point;
      final bStops = [for (var i = 0; i < 3; i++) GeoPoint(t1.latitude, lon + 0.0005 + i * 0.0096)];
      final b = route(id: 20, ref: '8', stops: bStops);
      final t2 = bStops.last;
      final cStops = [for (var i = 0; i < 3; i++) GeoPoint(t2.latitude + 0.0005 + i * kmLat, t2.longitude)];
      final c = route(id: 30, ref: '9', stops: cStops);
      final dest = GeoPoint(cStops.last.latitude + hundredMetersLat, cStops.last.longitude);
      // 出発地から目的地まで直通の遅くない路線があれば、7→8→9 は出さない。
      final direct = route(id: 40, ref: '50', stops: [origin, GeoPoint(t1.latitude, dest.longitude), dest]);
      final result = LocalPlanner.plan([a, b, c, direct], origin, dest);
      expect(result.where((i) => i.transferCount == 2), isEmpty);
      expect(result.map((i) => i.firstLeg.ref), contains('50'));
    });
  });
}
