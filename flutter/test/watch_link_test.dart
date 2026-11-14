import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/local_itinerary.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/local_planner.dart';
import 'package:osmbus/services/watch_link.dart';
import 'package:osmbus/state/trip_controller.dart';

import 'fixtures.dart';
import 'nav_origin_alight_color_test.dart' show east, line, lon, makeController, settle;

void main() {
  group('Apple Watch の長押しは、番号表の長押しと同じ意味', () {
    // 09 で北へ 2 停留所、30m 歩いて E10 で先へ。
    final a = route(id: 9, ref: '09', stops: northward(21.0, lon, 4));
    final bStops = [for (final s in a.stops) east(s.point, 30), GeoPoint(21.0 + 5 * kmLat, lon + 0.0003)];
    final b = route(id: 10, ref: 'E10', stops: bStops);

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

    test('乗車中は今の番号と、直後の乗換の番号を出す', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      final snapshot = WatchLink.snapshotOf(controller);
      expect(snapshot['isRiding'], true);
      expect(snapshot['busNumber'], '09');
      expect(snapshot['nextTransferBusNumber'], 'E10');
      expect(snapshot['boardBusNumber'], isNull);
    });

    test('乗換先の番号を長押しすると、同じ旅程の次のレグに乗り換える', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      expect(controller.longPressBusNumber('e10'), isTrue, reason: '大文字小文字は区別しない');
      expect(controller.riding!.ref, 'E10');
      expect(controller.riding!.legIndex, 1);
      expect(controller.nextTransferRef, isNull, reason: '最終区間では乗換を出さない');
    });

    test('乗っている番号を長押しすると降り、乗換先を大きく出して長押しで乗れる', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      expect(controller.longPressBusNumber('09'), isTrue);
      expect(controller.riding, isNull);
      final snapshot = WatchLink.snapshotOf(controller);
      expect(snapshot['isRiding'], false);
      expect(snapshot['boardBusNumber'], 'E10');
      expect(snapshot['distanceText'], isNull);

      expect(controller.longPressBusNumber('E10'), isTrue);
      expect(controller.riding!.ref, 'E10');
      expect(controller.riding!.legIndex, 1);
      expect(controller.boardableRef, isNull);
    });

    test('関係ない番号は何もしない', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      expect(controller.longPressBusNumber('99'), isFalse);
      expect(controller.riding!.ref, '09');
    });

    test('ナビ中止で乗換先を忘れる', () async {
      final controller = await riding();
      addTearDown(controller.dispose);
      controller.longPressBusNumber('09');
      await controller.cancelNavigation();
      expect(controller.boardableRef, isNull);
      expect(controller.longPressBusNumber('E10'), isFalse);
    });
  });

  test('未乗車で判定が 1 系統に決まったら、その番号を長押しで乗れる', () async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    controller.debugSetOrigin(east(line.stops[0].point, 60));
    await controller.setDestination(Destination(name: 'goal', point: east(line.stops[4].point, 60)));
    await settle(controller);
    controller
      ..appendDigit('7')
      ..submitInput();
    expect(controller.boardableRef, '07');
    expect(WatchLink.snapshotOf(controller)['boardBusNumber'], '07');
    expect(controller.longPressBusNumber('07'), isTrue);
    expect(controller.riding!.ref, '07');
    final snapshot = WatchLink.snapshotOf(controller);
    expect(snapshot['distanceText'], isA<String>());
  });
}
