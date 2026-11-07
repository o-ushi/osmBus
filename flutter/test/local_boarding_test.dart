import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/boarding_decision.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/services/local_planner.dart';

import 'fixtures.dart';

void main() {
  const lon = 105.8;
  final stops = northward(21.0, lon, 4);
  final origin = GeoPoint(21.0 - hundredMetersLat, lon);
  final destination = GeoPoint(stops.last.latitude + hundredMetersLat, lon);
  final routes = [
    route(id: 2, ref: '35B', stops: [for (final s in stops) GeoPoint(s.latitude, s.longitude + 0.0003)]),
    route(id: 1, ref: '35A', stops: stops),
    route(id: 3, ref: '36', stops: stops),
  ];

  BoardingDecision decide(String input, GeoPoint from) =>
      BoardingJudge.decide(input, LocalPlanner.plan(routes, from, destination));

  test('35A と 35B がどちらも条件を満たす → boardIfVariant の名前が 35A, 35B', () {
    final decision = decide('35', origin);
    expect(decision, isA<BoardIfVariant>());
    final board = decision as BoardIfVariant;
    expect(board.names, ['35A', '35B']);
    expect(board.alightStopName, '35A-stop3');
    expect(board.direction.isAny, isFalse);
    expect(board.direction.compassIndex, 0);
  });

  test('1 系統だけでも variant', () {
    final decision = decide('36', origin);
    expect(decision, isA<BoardIfVariant>());
    expect((decision as BoardIfVariant).names, ['36']);
  });

  test('ゼロ埋め入力も同じ番号', () {
    final decision = decide('035', origin);
    expect((decision as BoardIfVariant).names, ['35A', '35B']);
  });

  test('どちらも半径外 → doNotBoard', () {
    final far = GeoPoint(21.0 - 3 * kmLat, lon);
    expect(decide('35', far), isA<DoNotBoard>());
  });

  test('番号が無い → doNotBoard', () {
    expect(decide('12', origin), isA<DoNotBoard>());
  });

  test('向きが 120 度を超えて開けば「どちらでも可」', () {
    final east = [for (var i = 0; i < 4; i++) GeoPoint(21.0, lon + i * 0.0096)];
    final mixed = [
      route(id: 1, ref: '35A', stops: [origin, destination]),
      route(id: 2, ref: '35B', stops: [origin, east.last]),
    ];
    final itineraries = [
      ...LocalPlanner.plan(mixed, origin, destination),
      ...LocalPlanner.plan(mixed, origin, east.last),
    ];
    // 北向きと東向きは 90 度なので平均。
    final decision = BoardingJudge.decide('35', itineraries) as BoardIfVariant;
    expect(decision.direction.isAny, isFalse);

    final south = route(id: 3, ref: '35C', stops: [origin, GeoPoint(origin.latitude - 3 * kmLat, lon)]);
    final opposite = [
      ...LocalPlanner.plan([mixed.first], origin, destination),
      ...LocalPlanner.plan([south], origin, south.stops.last.point),
    ];
    expect((BoardingJudge.decide('35', opposite) as BoardIfVariant).direction.isAny, isTrue);
  });
}
