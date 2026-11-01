import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/l10n/app_localizations.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/route_review.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:osmbus/ui/stop_order_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stop_order_test.dart' show at, stop, osmRoute, backtracking, straight, ids;

void main() {
  late TripController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = TripController(
      prefs: await SharedPreferences.getInstance(),
      sync: const UnsupportedCatalogSync(),
      requestsLocationOnLaunch: false,
    );
    controller.debugSetCatalog(CatalogSnapshot(routes: [backtracking, straight]));
  });

  tearDown(() => controller.dispose());

  List<RouteStop> shown(int relationId) => controller.shownRoute(relationId)!.stops;

  Future<Map<String, dynamic>> saved() async =>
      jsonDecode((await SharedPreferences.getInstance()).getString('stopOrder.applied')!) as Map<String, dynamic>;

  group('ステップ 3: 所見ごとに採用する', () {
    test('順序の所見だけ採用すると、その路線の表示順は提案の順。別の路線は変わらない。新しい形で保存', () async {
      final order = controller.reviewRoute(1)!.order!;
      controller.applyOrderFinding(1, order);
      expect(ids(shown(1)), ids(order.proposal));
      expect(ids(shown(2)), ids(straight.stops));
      final entry = (await saved())['1'] as List;
      expect(entry.first, isA<Map>());
      expect([for (final e in entry) (e as Map)['id']], ids(order.proposal));
      expect((await saved()).containsKey('2'), isFalse);
      // 計算し直すと、順序の所見は無くなる。
      expect(controller.reviewRoute(1)!.order, isNull);
    });

    test('場所の差し替えは、その 1 件の ID と座標だけが変わる', () {
      final route = osmRoute(3, '40', [
        stop(301, 'Start', 0),
        stop(302, 'Nhà văn hóa', 1500, east: 400),
        stop(303, 'End', 3000),
      ]);
      final other = osmRoute(4, '41', [stop(401, 'Nhà Văn Hóa', 1600, east: 20)]);
      controller.debugSetCatalog(CatalogSnapshot(routes: [route, other]));
      final place = controller.reviewRoute(3)!.places.single;
      controller.applyPlaceFinding(3, place);
      final stops = shown(3);
      expect(ids(stops), [301, 401, 303]);
      expect(stops[1].point, other.stops.single.point);
      expect(stops[0].point, route.stops[0].point);
      expect(stops[2].point, route.stops[2].point);
      expect(controller.reviewRoute(3)!.places, isEmpty);
      expect(ids(shown(4)), [401], reason: '他の路線は変わらない');
    });

    test('「OSM の並びに戻す」で記憶が消え、OSM のメンバー順に戻る（読み込み時の並べ替え後ではない）', () async {
      controller.applyOrderFinding(1, controller.reviewRoute(1)!.order!);
      controller.forgetCustomStops(1);
      expect(controller.hasCustomStops(1), isFalse);
      expect(ids(shown(1)), [101, 104, 102, 103]);
      expect((await SharedPreferences.getInstance()).getString('stopOrder.applied'), isNull);
    });

    test('過不足の候補は自動で足さない', () {
      final partner = osmRoute(9, '32', [stop(104, 'D', 3000), stop(901, 'Ngã tư', 2500, east: 20)],
          from: 'D', to: 'A');
      controller.debugSetCatalog(CatalogSnapshot(routes: [backtracking, partner]));
      final review = controller.reviewRoute(1)!;
      expect(review.membership.fromPartner, isNotEmpty);
      controller.applyOrderFinding(1, review.order!);
      expect(ids(shown(1)), isNot(contains(901)));
    });
  });

  group('ステップ 4: 自分で直す', () {
    test('ドラッグした順を保存すると、その路線の表示順がその順。別の路線は変わらない', () {
      final s = backtracking.stops;
      controller.saveCustomStops(1, [s[0], s[3], s[1], s[2]]);
      expect(ids(shown(1)), [101, 103, 104, 102]);
      expect(ids(shown(2)), ids(straight.stops));
    });

    test('負の ID の停留所を足して保存すると、その名前と座標が残る。他の路線の stops には入らない', () {
      final id = controller.newLocalStopId();
      expect(id, isNegative);
      final mine = RouteStop(id: id, name: 'Nhà tôi', latitude: at(2500).latitude, longitude: at(2500).longitude);
      controller.saveCustomStops(1, [...shown(1), mine]);
      expect(shown(1).last.id, id);
      expect(shown(1).last.name, 'Nhà tôi');
      expect(shown(1).last.point, at(2500));
      expect(ids(shown(2)), isNot(contains(id)));
      final next = controller.newLocalStopId();
      expect(next, isNot(id));
      expect(next, isNegative);
    });

    test('1 件削除して保存すると、その停留所は表示から消える。1 件だけの保存はしない', () {
      controller.saveCustomStops(1, shown(1).where((s) => s.id != 104).toList());
      expect(ids(shown(1)), [101, 102, 103]);
      controller.saveCustomStops(1, [shown(1).first]);
      expect(ids(shown(1)), [101, 102, 103]);
    });

    test('正の ID の座標を変えて保存すると、表示の座標は変えた値で、名前は OSM のまま', () {
      final moved = at(1000, eastMeters: 40);
      final stops = [...shown(1)];
      stops[2] = RouteStop(id: 102, name: 'renamed', latitude: moved.latitude, longitude: moved.longitude);
      controller.saveCustomStops(1, stops);
      expect(shown(1)[2].point, moved);
      expect(shown(1)[2].name, 'B');
    });

    test('保存したあとに、もう一度順番を変えて保存できる', () {
      final s = backtracking.stops;
      controller.saveCustomStops(1, [s[0], s[2], s[3], s[1]]);
      controller.saveCustomStops(1, [s[1], s[0], s[2], s[3]]);
      expect(ids(shown(1)), [104, 101, 102, 103]);
    });

    test('「OSM の並びに戻す」で、足した停留所も座標の変更も消え、OSM のメンバー順に戻る', () {
      final moved = at(0, eastMeters: 40);
      final stops = [...shown(1)];
      stops[0] = RouteStop(id: 101, name: 'A', latitude: moved.latitude, longitude: moved.longitude);
      controller.saveCustomStops(1, [...stops, stop(controller.newLocalStopId(), 'Mine', 2500)]);
      controller.forgetCustomStops(1);
      expect(ids(shown(1)), [101, 104, 102, 103]);
      expect(shown(1).first.point, backtracking.stops.first.point);
    });

    test('過不足の候補（復路・他路線）は、編集中の停留所で作り直せる', () {
      final partner = osmRoute(9, '32', [stop(104, 'D', 3000), stop(901, 'Ngã tư', 2500, east: 20)],
          from: 'D', to: 'A');
      controller.debugSetCatalog(CatalogSnapshot(routes: [backtracking, partner]));
      final withCandidate = controller.reviewRoute(1, stops: shown(1))!;
      expect([for (final c in withCandidate.membership.fromPartner) c.stop.id], [901]);
      final added = controller.reviewRoute(1, stops: [...shown(1), partner.stops[1]])!;
      expect(added.membership.fromPartner, isEmpty);
    });

    Future<void> openEditor(WidgetTester tester, int relationId) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStopOrderEditor(context, controller, relationId),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    IconButton deleteButton(WidgetTester tester, int index) => tester.widgetList<IconButton>(
          find.ancestor(of: find.byIcon(CupertinoIcons.minus_circle), matching: find.byType(IconButton)),
        ).elementAt(index);

    testWidgets('2 件のときは削除できず、1 件も違わなければ「この順で使う」は押せない', (tester) async {
      final two = osmRoute(12, '12', [stop(1201, 'X', 0), stop(1202, 'Y', 1000)]);
      controller.debugSetCatalog(CatalogSnapshot(routes: [two]));
      await openEditor(tester, 12);
      expect(deleteButton(tester, 0).onPressed, isNull);
      expect(deleteButton(tester, 1).onPressed, isNull);
      final use = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'この順で使う'));
      expect(use.onPressed, isNull);
    });

    testWidgets('1 件削除して「この順で使う」で保存し、もう一度開いても編集できる', (tester) async {
      await openEditor(tester, 1);
      expect(deleteButton(tester, 1).onPressed, isNotNull);
      await tester.tap(find.byIcon(CupertinoIcons.minus_circle).at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'この順で使う'));
      await tester.pumpAndSettle();
      expect(ids(shown(1)), [101, 102, 103]);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
      expect(find.widgetWithText(TextButton, 'この路線の修正をリセット'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'この路線の修正をリセット'));
      await tester.pumpAndSettle();
      expect(ids(shown(1)), [101, 104, 102, 103]);
    });
  });

  test('所見の種類が空なら RouteReview の各要素は空', () {
    final review = RouteReviewer.review(straight, [straight]);
    expect(review.order, isNull);
    expect(review.ends, isNull);
    expect(review.places, isEmpty);
    expect(review.membership.isEmpty, isTrue);
  });
}
