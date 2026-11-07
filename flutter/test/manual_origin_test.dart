import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/geo.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const gps = GeoPoint(21.0285, 105.8542);
  const picked = GeoPoint(21.0200, 105.7819);
  const goal = GeoPoint(21.0400, 105.8500);

  late TripController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = TripController(
      prefs: await SharedPreferences.getInstance(),
      sync: const UnsupportedCatalogSync(),
      requestsLocationOnLaunch: false,
    );
    controller.debugSetOrigin(gps);
    await controller.setDestination(const Destination(name: 'goal', point: goal));
  });

  tearDown(() => controller.dispose());

  test('地図で選んだ出発地が現在地より優先され、クリアで現在地に戻る', () {
    expect(controller.origin, gps);
    controller.setManualOrigin(const Destination(name: 'Skylake', point: picked));
    expect(controller.origin, picked);
    expect(controller.manualOrigin?.name, 'Skylake');
    expect(controller.distanceLeftMeters, closeTo(Geo.distance(picked, goal), 0.001));

    controller.clearManualOrigin();
    expect(controller.manualOrigin, isNull);
    expect(controller.origin, gps);
    expect(controller.distanceLeftMeters, closeTo(Geo.distance(gps, goal), 0.001));
  });
}
