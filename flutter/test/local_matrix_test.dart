import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/bus_matrix.dart';
import 'package:osmbus/models/local_itinerary.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/local_planner.dart';

import 'fixtures.dart';

void main() {
  const lon = 105.8;
  final origin = GeoPoint(21.0 - hundredMetersLat, lon);
  final near = northward(21.0, lon, 4);
  // 乗車停留所が出発地から約 300m。
  final farther = northward(21.0 + 2 * hundredMetersLat, lon, 4)..[3] = near[3];
  final destination = GeoPoint(near.last.latitude + hundredMetersLat, lon);

  test('同じ方位・同じ列・同じ番号は徒歩が短い方だけ残る', () {
    final itineraries = LocalPlanner.plan(
      [
        route(id: 5, ref: '12', stops: farther),
        route(id: 6, ref: '12', stops: near),
      ],
      origin,
      destination,
    );
    expect(itineraries, hasLength(2));
    expect(itineraries.every((i) => i.column == 0), isTrue);

    final rows = BusMatrix.byDirection(itineraries);
    expect(rows, hasLength(1));
    final cell = rows.single.cells[0];
    expect(cell, hasLength(1));
    expect(cell.single.itinerary.firstLeg.relationId, 6);

    final flat = BusMatrix.flat(itineraries, mode: TableSortMode.distance);
    expect(flat, hasLength(1));
    expect(flat.single.itinerary.firstLeg.relationId, 6);
  });

  test('同じ方位の同じ番号は乗換の少ない列にだけ出る', () {
    const stop = RouteStop(id: 1, name: 's', latitude: 21.0, longitude: lon);
    ItineraryLeg leg(int id, String ref) => ItineraryLeg(
          relationId: id,
          ref: ref,
          routeName: ref,
          boardIndex: 0,
          alightIndex: 1,
          boardStop: stop,
          alightStop: stop,
          path: const [],
          rideMeters: 1000,
        );
    LocalItinerary trip(List<ItineraryLeg> legs, double walk) =>
        LocalItinerary(legs: legs, walkMeters: walk, bearing: 180);

    final itineraries = [
      trip([leg(1, '23'), leg(2, '7'), leg(3, '9')], 100),
      trip([leg(4, '23'), leg(5, '7')], 400),
      trip([leg(6, '31'), leg(7, '7'), leg(8, '9')], 100),
    ];
    final cells = BusMatrix.byDirection(itineraries).single.cells;
    expect(cells[1].map((e) => e.token), ['23']);
    expect(cells[2].map((e) => e.token), ['31']);
    expect(BusMatrix.flat(itineraries, mode: TableSortMode.transfers).map((e) => e.token), ['23', '31']);
  });

  test('フラット距離順: 徒歩の差が 100m 未満なら乗換の少ない方が上', () {
    const stop = RouteStop(id: 1, name: 's', latitude: 21.0, longitude: lon);
    ItineraryLeg leg(int id, String ref) => ItineraryLeg(
          relationId: id,
          ref: ref,
          routeName: ref,
          boardIndex: 0,
          alightIndex: 1,
          boardStop: stop,
          alightStop: stop,
          path: const [],
          rideMeters: 1000,
        );
    final itineraries = [
      LocalItinerary(legs: [leg(1, '11'), leg(2, '159'), leg(3, '32')], walkMeters: 410, bearing: 180),
      LocalItinerary(legs: [leg(4, '34')], walkMeters: 450, bearing: 270),
      LocalItinerary(legs: [leg(5, '50')], walkMeters: 700, bearing: 270),
    ];
    final order = BusMatrix.flat(itineraries, mode: TableSortMode.distance).map((e) => e.token);
    expect(order, ['34', '11', '50']);
  });

  test('行は relationId 昇順で方位が最初に現れた順', () {
    final east = [for (var i = 0; i < 2; i++) GeoPoint(21.0, lon + i * 0.0096)];
    final eastDest = GeoPoint(21.0, east.last.longitude + 0.0005);
    final itineraries = [
      ...LocalPlanner.plan([route(id: 9, ref: '1', stops: near)], origin, destination),
      ...LocalPlanner.plan([route(id: 3, ref: '2', stops: east)], origin, eastDest),
    ];
    final rows = BusMatrix.byDirection(itineraries);
    expect(rows.map((r) => r.compassIndex), [2, 0]);
  });

  test('フラット: 乗換回数基準は列の昇順', () {
    final a = route(id: 10, ref: '7', stops: northward(21.0, lon, 3));
    final t = a.stops.last.point;
    final b = route(id: 20, ref: '99', stops: [
      GeoPoint(t.latitude + hundredMetersLat, lon),
      GeoPoint(t.latitude + hundredMetersLat + kmLat, lon),
    ]);
    final direct = route(id: 30, ref: '50', stops: [
      GeoPoint(21.0, lon + 0.004),
      GeoPoint(t.latitude + hundredMetersLat + kmLat, lon + 0.004),
    ]);
    final dest = GeoPoint(b.stops.last.latitude + hundredMetersLat, lon);
    final itineraries = LocalPlanner.plan([a, b, direct], origin, dest);
    final flat = BusMatrix.flat(itineraries, mode: TableSortMode.transfers);
    expect(flat.map((e) => e.column).toList(), orderedEquals([...flat.map((e) => e.column)]..sort()));
    final transfer = flat.firstWhere((e) => e.column == 1 && e.firstRef == '7');
    expect(transfer.chain, '7 → 99');
  });
}
