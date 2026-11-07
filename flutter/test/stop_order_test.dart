import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/catalog_sync.dart';
import 'package:osmbus/services/route_review.dart';
import 'package:osmbus/services/stop_order_repair.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double lon = 105.78;
const double lat0 = 21.03;

/// 線上 [meters] の地点（北向き）。[eastMeters] だけ線から東へ離す。
GeoPoint at(double meters, {double eastMeters = 0}) => GeoPoint(lat0 + meters / 110574, lon + eastMeters / 104000);

RouteStop stop(int id, String name, double meters, {double east = 0}) {
  final p = at(meters, eastMeters: east);
  return RouteStop(id: id, name: name, latitude: p.latitude, longitude: p.longitude);
}

/// 北へ 0〜[length] m の直線の路線。
RouteRecord osmRoute(int id, String ref, List<RouteStop> stops, {double length = 3000, String? from, String? to}) =>
    RouteRecord(
      relationId: id,
      ref: ref,
      name: ref,
      from: from,
      to: to,
      stops: stops,
      polylineSegments: [
        [for (var m = 0.0; m <= length; m += 100) at(m)],
      ],
      hasGeometry: true,
    );

/// メンバー順が A(0), D(3000), B(1000), C(2000)。線の上で D から B へ 2km 戻る。
final backtracking = osmRoute(1, '32', [
  stop(101, 'A', 0),
  stop(104, 'D', 3000),
  stop(102, 'B', 1000),
  stop(103, 'C', 2000),
], from: 'A', to: 'D');

final straight = osmRoute(2, '33', [stop(201, 'P', 0), stop(202, 'Q', 1000), stop(203, 'R', 2000)]);

List<int> ids(List<RouteStop> stops) => [for (final s in stops) s.id];

void main() {
  Future<TripController> controllerWith(List<RouteRecord> routes, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final controller = TripController(
      prefs: await SharedPreferences.getInstance(),
      sync: const UnsupportedCatalogSync(),
      requestsLocationOnLaunch: false,
    );
    controller.debugSetCatalog(CatalogSnapshot(routes: routes));
    return controller;
  }

  List<RouteStop> shown(TripController c, int relationId) => c.shownRoute(relationId)!.stops;

  group('ステップ 1: 読み込み時は並べ替えない', () {
    test('線の上で 1km 以上戻っている路線を読み込んでも、stops の順は OSM のまま', () async {
      final c = await controllerWith([backtracking]);
      addTearDown(c.dispose);
      expect(ids(shown(c, 1)), [101, 104, 102, 103]);
      expect(c.hasCustomStops(1), isFalse);
      expect((await SharedPreferences.getInstance()).getString('stopOrder.applied'), isNull);
    });

    test('古い ID 配列が路線の停留所の並べ替えなら、その順。名前と座標は OSM のもの', () async {
      final c = await controllerWith([backtracking, straight], prefs: {
        'stopOrder.applied': jsonEncode({
          '1': [101, 102, 103, 104],
        }),
      });
      addTearDown(c.dispose);
      expect(ids(shown(c, 1)), [101, 102, 103, 104]);
      expect(shown(c, 1)[1].point, backtracking.stops[2].point);
      expect(ids(shown(c, 2)), ids(straight.stops));
    });

    test('古い ID 配列に一つでも知らない ID があれば、その路線は OSM の順で、記憶は捨てる', () async {
      final c = await controllerWith([backtracking], prefs: {
        'stopOrder.applied': jsonEncode({
          '1': [101, 102, 103, 999],
        }),
      });
      addTearDown(c.dispose);
      expect(ids(shown(c, 1)), [101, 104, 102, 103]);
      expect(c.hasCustomStops(1), isFalse);
      expect((await SharedPreferences.getInstance()).getString('stopOrder.applied'), isNull);
    });

    test('新しい形: 正の ID は OSM の名前と覚えた座標。消えた ID は落ち、負の ID は残る', () async {
      final moved = at(1000, eastMeters: 30);
      final c = await controllerWith([backtracking], prefs: {
        'stopOrder.applied': jsonEncode({
          '1': [
            {'id': 101, 'name': 'old name', 'latitude': at(0).latitude, 'longitude': at(0).longitude},
            {'id': 102, 'name': 'B', 'latitude': moved.latitude, 'longitude': moved.longitude},
            {'id': 555, 'name': 'gone', 'latitude': at(1500).latitude, 'longitude': at(1500).longitude},
            {'id': -1, 'name': 'Mine', 'latitude': at(2500).latitude, 'longitude': at(2500).longitude},
          ],
        }),
      });
      addTearDown(c.dispose);
      final stops = shown(c, 1);
      expect(ids(stops), [101, 102, -1]);
      expect(stops[0].name, 'A', reason: '正の ID の名前は OSM');
      expect(stops[1].point, moved, reason: '座標は覚えたもの');
      expect(stops[2].name, 'Mine');
      expect(stops[2].point, at(2500));
      expect(c.hasCustomStops(1), isTrue);
    });

    test('他の路線にある既存の停留所（差し替え・追加で選んだもの）は残り、名前はその OSM の停留所', () async {
      final c = await controllerWith([backtracking, straight], prefs: {
        'stopOrder.applied': jsonEncode({
          '1': [
            {'id': 101, 'name': 'A', 'latitude': at(0).latitude, 'longitude': at(0).longitude},
            {'id': 202, 'name': 'old', 'latitude': at(1000).latitude, 'longitude': at(1000).longitude},
          ],
        }),
      });
      addTearDown(c.dispose);
      expect(ids(shown(c, 1)), [101, 202]);
      expect(shown(c, 1)[1].name, 'Q');
      expect(ids(shown(c, 2)), ids(straight.stops), reason: '他の路線の stops は変えない');
    });

    test('整えた結果が 2 件未満なら記憶ごと捨てて OSM の並びに戻る', () async {
      final c = await controllerWith([backtracking], prefs: {
        'stopOrder.applied': jsonEncode({
          '1': [
            {'id': 555, 'name': 'gone', 'latitude': at(0).latitude, 'longitude': at(0).longitude},
            {'id': -1, 'name': 'Mine', 'latitude': at(2500).latitude, 'longitude': at(2500).longitude},
          ],
        }),
      });
      addTearDown(c.dispose);
      expect(ids(shown(c, 1)), [101, 104, 102, 103]);
      expect(c.hasCustomStops(1), isFalse);
      expect((await SharedPreferences.getInstance()).getString('stopOrder.applied'), isNull);
    });

    test('記憶のある路線が路線データの更新で ID を失うと、その要素だけ落ちる', () async {
      final c = await controllerWith([backtracking]);
      addTearDown(c.dispose);
      c.saveCustomStops(1, [...backtracking.stops, stop(-3, 'Mine', 2500)]);
      final changed = backtracking.copyWith(stops: backtracking.stops.where((s) => s.id != 104).toList());
      c.debugSetCatalog(CatalogSnapshot(routes: [changed]));
      expect(ids(shown(c, 1)), [101, 102, 103, -3]);
    });
  });

  group('ステップ 2: 所見', () {
    test('1km 以上戻っている路線では順序の所見が 1 件あり、提案は StopOrderRepair と同じ順', () {
      final review = RouteReviewer.review(backtracking, [backtracking, straight]);
      final order = review.order!;
      expect(ids(order.proposal), ids(StopOrderRepair.repair(backtracking).stops));
      expect(ids(order.proposal), [101, 102, 103, 104]);
      expect(order.backtracks, hasLength(1));
      final b = order.backtracks.single;
      expect(b.stop.name, 'B');
      expect(b.after?.name, 'A');
      expect(b.before?.name, 'C');
      expect(order.partnerDisagrees, isFalse);
    });

    test('記録上の端が途中でも、方面の着点側の端を終点にする', () {
      // メンバー順は中央から西へ行き、次の区間が東から中央へ戻る。
      // 記録上の末端は中央だが、繋がった線の端は東（Long Biên）と西（Smart City）。
      GeoPoint ew(double eastMeters) => GeoPoint(lat0, lon + eastMeters / 104000);
      final west = ew(0);
      final mid = ew(1500);
      final east = ew(3000);
      RouteStop atPoint(int id, String name, GeoPoint p) =>
          RouteStop(id: id, name: name, latitude: p.latitude, longitude: p.longitude);
      final route = osmRoute(5, 'E05', [
        atPoint(1, 'Điểm đỗ xe buýt Smart City', west),
        atPoint(2, 'Điểm đỗ xe buýt Long Biên', east),
        atPoint(3, '72-74 Thụy Khuê', mid),
      ], from: 'Long Biên', to: 'Khu đô thị Smart City').copyWith(polylineSegments: [
        [mid, west],
        [east, mid],
      ]);
      final proposal = RouteReviewer.review(route, [route]).order!.proposal;
      expect(proposal.last.name, contains('Smart City'));
      expect(proposal.first.name, contains('Long Biên'));
      expect(proposal.last.longitude, lessThan(proposal.first.longitude));

      // 直した結果は、終点の旗が線の途中（中央）に残る並び。西の端へ直す提案が出る。
      final misplaced = route.copyWith(stops: [proposal[1], proposal.last, proposal.first]);
      final ends = RouteReviewer.review(misplaced, [misplaced]).ends!;
      expect(ends.proposal, isNotNull);
      expect(ends.proposal!.last.name, contains('Smart City'));
      expect(ends.proposal!.last.longitude, lessThan(mid.longitude));
    });

    test('戻っていない路線では順序の所見が無い', () {
      expect(RouteReviewer.review(straight, [backtracking, straight]).order, isNull);
    });

    test('同じ停留所 ID が 2 回出る路線は順序の所見を出さない', () {
      final loop = backtracking.copyWith(stops: [...backtracking.stops, backtracking.stops.first]);
      expect(RouteReviewer.review(loop, [loop]).order, isNull);
    });

    test('復路と、逆にしても前後が違えば 1 行足す。戻りが無ければ出さない', () {
      // 復路（始点と終点が入れ替わり）なのに、共有している停留所が同じ向きで並んでいる。
      final partner = osmRoute(9, '32', [stop(101, 'A', 0), stop(102, 'B', 1000), stop(103, 'C', 2000)],
          from: 'D', to: 'A');
      expect(RouteReviewer.review(backtracking, [backtracking, partner]).order!.partnerDisagrees, isTrue);

      final ok = osmRoute(8, '32', [stop(101, 'A', 0), stop(102, 'B', 1000)], from: 'A', to: 'D');
      expect(RouteReviewer.review(ok, [ok, partner]).order, isNull);
    });

    test('線から 400m 離れ、他路線に同名で線の近くにある停留所があれば、それを差し替え候補にする', () {
      final route = osmRoute(3, '40', [
        stop(301, 'Start', 0),
        stop(302, 'Nhà văn hóa', 1500, east: 400),
        stop(303, 'End', 3000),
      ]);
      final other = osmRoute(4, '41', [
        stop(401, 'nha  van hoa ', 1600, east: 20),
        stop(402, 'Nhà văn hóa', 2900, east: 100),
      ]);
      final places = RouteReviewer.review(route, [route, other]).places;
      expect(places, hasLength(1));
      expect(places.single.stop.id, 302);
      expect(places.single.lineMeters, closeTo(400, 2));
      expect(places.single.replacement?.stop.id, 401, reason: '線に一番近い 1 件');
      expect(places.single.replacement?.routeRef, '41');
    });

    test('同名が無ければ候補は無く、距離だけがある', () {
      final route = osmRoute(3, '40', [
        stop(301, 'Start', 0),
        stop(302, 'Nhà văn hóa', 1500, east: 400),
        stop(303, 'End', 3000),
      ]);
      final other = osmRoute(4, '41', [stop(401, 'Chợ', 1600, east: 20)]);
      final place = RouteReviewer.review(route, [route, other]).places.single;
      expect(place.replacement, isNull);
      expect(place.lineMeters, closeTo(400, 2));
    });

    test('短い名前が長い名前に含まれるだけでは、場所の候補にしない', () {
      final route = osmRoute(3, '40', [
        stop(301, 'Start', 0),
        stop(302, 'Nhà văn hóa', 1500, east: 400),
        stop(303, 'End', 3000),
      ]);
      final other = osmRoute(4, '41', [stop(401, 'Nhà văn hóa Cầu Giấy', 1600, east: 20)]);
      expect(RouteReviewer.review(route, [route, other]).places.single.replacement, isNull);
    });

    test('復路の停留所が線から 50m 以内で、この路線に入っていなければ過不足に出る。提案には入らない', () {
      final partner = osmRoute(9, '32', [
        stop(104, 'D', 3000),
        stop(901, 'Ngã tư', 2500, east: 20),
        stop(101, 'A', 0),
      ], from: 'D', to: 'A');
      final other = osmRoute(5, '50', [stop(501, 'Bến', 1500, east: 30), stop(502, 'Xa', 1500, east: 300)]);
      final review = RouteReviewer.review(backtracking, [backtracking, partner, other]);
      expect(review.partner?.relationId, 9);
      expect([for (final c in review.membership.fromPartner) c.stop.id], [901]);
      expect([for (final c in review.membership.fromOthers) c.stop.id], [501]);
      expect(ids(review.order!.proposal), isNot(contains(901)));
      // B と C は復路に同じ ID も 80m 以内の停留所も無い。
      expect(ids(review.membership.onlyHere).toSet(), {102, 103});
    });

    test('相手の路線が無ければ「この方向にだけある停留所」は出さない。共有数が同点なら相手は無し', () {
      final x = osmRoute(10, '32', [stop(101, 'A', 0)]);
      final y = osmRoute(11, '32', [stop(102, 'B', 1000)]);
      final review = RouteReviewer.review(backtracking, [backtracking, x, y]);
      expect(review.partner, isNull);
      expect(review.membership.onlyHere, isEmpty);
    });

    test('名前が含まれるだけの停留所は「同じ停留所」として扱わない（この方向にだけある）', () {
      final route = osmRoute(6, '60', [stop(601, 'Cầu Giấy', 0), stop(602, 'End', 3000)], from: 'X', to: 'Y');
      final partner = osmRoute(7, '60', [stop(602, 'End', 3000), stop(701, 'Cầu Giấy 2', 300)], from: 'Y', to: 'X');
      final review = RouteReviewer.review(route, [route, partner]);
      expect(ids(review.membership.onlyHere), [601]);
    });

    test('StopNames は空白・大文字小文字・ダイアクリティカルだけを無視する', () {
      expect(StopNames.same('  Cầu   Giấy ', 'cau giay'), isTrue);
      expect(StopNames.same('Cầu Giấy', 'Cầu Giấy 2'), isFalse);
      expect(StopNames.same('', ''), isFalse);
    });

    test('レビューを作るだけでは何も保存しない', () async {
      final c = await controllerWith([backtracking, straight]);
      addTearDown(c.dispose);
      expect(c.reviewRoute(1)?.order, isNotNull);
      expect(ids(shown(c, 1)), [101, 104, 102, 103]);
      expect((await SharedPreferences.getInstance()).getString('stopOrder.applied'), isNull);
    });
  });
}
