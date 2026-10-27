import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/bus_matrix.dart';
import 'package:osmbus/models/local_itinerary.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 71 で乗換停留所まで行き、28 で目的地近くまで行く。
void main() {
  late TripController controller;
  const origin = GeoPoint(21.0, 105.8);
  const board71 = RouteStop(id: 1, name: 'A', latitude: 21.0, longitude: 105.8);
  const transfer = RouteStop(id: 2, name: 'B', latitude: 21.02, longitude: 105.8);
  const board28 = RouteStop(id: 3, name: 'B2', latitude: 21.0202, longitude: 105.8);
  const alight28 = RouteStop(id: 4, name: 'C', latitude: 21.04, longitude: 105.8);

  ItineraryLeg leg(int relationId, String ref, RouteStop from, RouteStop to) => ItineraryLeg(
        relationId: relationId,
        ref: ref,
        routeName: ref,
        boardIndex: 0,
        alightIndex: 1,
        boardStop: from,
        alightStop: to,
        path: [from.point, to.point],
        rideMeters: Geo.distance(from.point, to.point),
      );

  LocalItinerary trip() => LocalItinerary(
        legs: [leg(71, '71', board71, transfer), leg(28, '28', board28, alight28)],
        walkMeters: 100,
        bearing: 0,
      );

  MatrixEntry entry() => MatrixEntry(token: '71', itinerary: trip());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    controller = TripController(prefs: prefs, sync: const UnsupportedCatalogSync(), requestsLocationOnLaunch: false);
    controller.debugSetOrigin(origin);
  });

  tearDown(() => controller.dispose());

  test('71 を長押しすると 71 に乗り、乗換停留所までの距離を出す', () {
    controller.toggleRiding(entry());
    expect(controller.riding?.ref, '71');
    expect(controller.riding?.alightStop.id, transfer.id);
    expect(controller.distanceLeftMeters, closeTo(Geo.distance(origin, transfer.point), 1));
    expect(controller.ridingLegIndexIn(trip()), 0);
    expect(controller.isRidingLeg(trip(), 0), isTrue);
    expect(controller.isRidingLeg(trip(), 1), isFalse);
  });

  test('続けて 28 を長押しすると乗り換えたとみなし、28 の降車停留所までの距離を出す', () {
    controller.toggleRiding(entry());
    controller.debugSetOrigin(board28.point);
    controller.toggleRiding(entry(), legIndex: 1);
    expect(controller.riding?.ref, '28');
    expect(controller.riding?.alightStop.id, alight28.id);
    expect(controller.distanceLeftMeters, closeTo(Geo.distance(board28.point, alight28.point), 1));
    expect(controller.ridingLegIndexIn(trip()), 1);
    expect(controller.isRidingLeg(trip(), 0), isFalse);
    expect(controller.isRidingLeg(trip(), 1), isTrue);
  });

  test('番号表が作り直されて 28 が直通の行になっていても、乗っている旅程のまま乗り換える', () {
    controller.toggleRiding(entry());
    final direct28 = LocalItinerary(legs: [leg(28, '28', board28, alight28)], walkMeters: 50, bearing: 0);
    controller.toggleRiding(MatrixEntry(token: '28', itinerary: direct28));
    expect(controller.riding?.ref, '28');
    expect(controller.ridingLegIndexIn(trip()), 1);
  });

  test('乗っている 28 をもう一度長押しすると降車する', () {
    controller.toggleRiding(entry());
    controller.toggleRiding(entry(), legIndex: 1);
    controller.toggleRiding(entry(), legIndex: 1);
    expect(controller.riding, isNull);
  });
}
