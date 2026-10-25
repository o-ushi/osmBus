import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osmbus/app.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/route_catalog_store.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:osmbus/ui/keypad.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端末上で UI を一通り操作する。`STAGE:` の行で外から画面を撮る。
/// 通信は地図タイルだけ。路線データはここで端末へ書く。
const hanoi = GeoPoint(21.0285, 105.8542);

RouteRecord _route(int id, String ref, String name, List<GeoPoint> points) => RouteRecord(
      relationId: id,
      ref: ref,
      name: name,
      osmTimestamp: '2026-01-01T00:00:00Z',
      stops: [
        for (var k = 0; k < points.length; k++)
          RouteStop(
            id: id * 100 + k,
            name: '$name ${k + 1}',
            latitude: points[k].latitude,
            longitude: points[k].longitude,
          ),
      ],
      polylineSegments: [points],
      hasGeometry: true,
      updatedAt: DateTime.utc(2026, 10, 25),
      anchorLatitude: hanoi.latitude,
      anchorLongitude: hanoi.longitude,
    );

CatalogSnapshot _sample() {
  final north = [for (var k = 0; k < 8; k++) GeoPoint(hanoi.latitude + 0.0045 * k, hanoi.longitude)];
  return CatalogSnapshot(syncedAt: DateTime.now().toUtc(), routes: [
    _route(1, '35A', 'Hoan Kiem', north),
    _route(2, '35B', 'Long Bien', [for (final p in north) GeoPoint(p.latitude, p.longitude + 0.0008)]),
    _route(3, '7', 'Ba Dinh',
        [for (var k = 0; k < 4; k++) GeoPoint(hanoi.latitude + 0.0045 * k, hanoi.longitude - 0.002)]),
    _route(4, '99', 'Tay Ho',
        [for (var k = 0; k < 6; k++) GeoPoint(hanoi.latitude + 0.0135 + 0.0045 * k, hanoi.longitude - 0.0005)]),
    _route(5, 'E12', 'Gia Lam',
        [for (var k = 0; k < 5; k++) GeoPoint(hanoi.latitude, hanoi.longitude + 0.006 * k)]),
    _route(6, '50', 'Hai Ba Trung', north.reversed.toList()),
  ]);
}

Future<void> _stage(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  // ignore: avoid_print
  print('STAGE:$name');
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> _tapKey(WidgetTester tester, String digit) async {
  await tester.tap(find.descendant(of: find.byType(Keypad), matching: find.text(digit)));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('トップ・判定・地図・乗車・設定・目的地', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setInt('privacy.thirdPartyConsent.version', 1);
    await prefs.setString(
      'destination',
      '{"name":"Ho Tay (test)","latitude":21.0590,"longitude":105.8542}',
    );
    final store = RouteCatalogStore();
    await store.save(_sample());

    final controller = TripController(
      prefs: prefs,
      store: store,
      sync: CatalogSync.forPlatform(store),
      requestsLocationOnLaunch: false,
    );
    await tester.pumpWidget(OsmBusApp(controller: controller));
    await controller.start();
    controller.debugSetOrigin(hanoi);

    await _waitFor(tester, find.text('35A'));
    await _stage(tester, 'matrix');

    // 番号入力画面へ。
    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('番号入力'));
    await _stage(tester, 'mainidle');

    await _tapKey(tester, '3');
    await _tapKey(tester, '5');
    await tester.pump(const Duration(milliseconds: 400));
    await _stage(tester, 'board35');

    await tester.tap(find.text('CLR'));
    await _tapKey(tester, '1');
    await _tapKey(tester, '2');
    await tester.pump(const Duration(milliseconds: 400));
    await _stage(tester, 'skip12');

    await tester.tap(find.text('CLR'));
    await _tapKey(tester, '3');
    await _tapKey(tester, '5');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('乗車開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('35A').last);
    await _stage(tester, 'riding');

    await tester.tap(find.text('降車'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLR'));

    // マトリクスへ戻る。
    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('マトリクス'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('35A').first);
    await _stage(tester, 'matrixriding');

    await tester.tap(find.text('35B').first);
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _stage(tester, 'map');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await _stage(tester, 'settings');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await _stage(tester, 'settings2');
    Navigator.of(tester.element(find.byType(ListView))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ho Tay (test)'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _stage(tester, 'picker');
  });
}
