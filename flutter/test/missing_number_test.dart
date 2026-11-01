import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/l10n/app_localizations.dart';
import 'package:osmbus/models/bus_matrix.dart';
import 'package:osmbus/models/missing_number.dart';
import 'package:osmbus/models/route_catalog.dart';
import 'package:osmbus/state/trip_controller.dart';
import 'package:osmbus/ui/bus_number_table.dart';
import 'package:osmbus/ui/missing_number_sheet.dart';

import 'fixtures.dart';

void main() {
  const lon = 105.8;
  final origin = GeoPoint(21.0, lon);
  final destination = GeoPoint(21.0 + 2 * kmLat, lon);
  final between = GeoPoint(21.0 + kmLat, lon);

  RouteRecord line(int id, String ref, List<GeoPoint> stops, {String? from, String? to}) =>
      route(id: id, ref: ref, stops: stops).copyWith(from: from, to: to);

  // 目的地の停留所がリストの先頭、出発地の停留所が末尾。番号表の直通には出ない並び。
  final reversed = line(1, 'E05', [destination, between, origin], from: 'Long Biên', to: 'Smart City');
  final forward = line(2, 'E05', [origin, between, destination], from: 'Smart City', to: 'Long Biên');
  final originOnly = line(3, 'E05', [origin, GeoPoint(21.0 + 8 * kmLat, lon)]);
  final other = line(4, '39', [origin, between, destination]);

  group('この区間に無い番号', () {
    test('停留所順が逆でも、両端に停留所があればこの区間の路線', () {
      final result = MissingNumber.find(
        [reversed, forward, originOnly, other],
        'E05',
        origin: origin,
        destination: destination,
      );
      expect(result.onSegment.map((r) => r.relationId), [1, 2]);
      expect(result.numberOnly.map((r) => r.relationId), [3]);
    });

    test('番号が違えば含めない', () {
      final result = MissingNumber.find([other], 'E05', origin: origin, destination: destination);
      expect(result.onSegment, isEmpty);
      expect(result.numberOnly, isEmpty);
    });

    test('空の入力は空', () {
      final result = MissingNumber.find([reversed], '  ', origin: origin, destination: destination);
      expect(result.onSegment, isEmpty);
    });
  });

  testWidgets('番号表に入口が出る', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(SizedBox(
      width: 400,
      height: 500,
      child: BusNumberTable(
        state: TableState.ready,
        sortMode: TableSortMode.transfers,
        rows: const [],
        flatEntries: const [],
        isRidingLeg: (_, _) => false,
        onReload: () {},
        onMissingNumber: () => taps++,
        onTap: (_) {},
        onLongPress: (_, _) {},
      ),
    )));

    expect(find.text('この区間に無い番号'), findsOneWidget);
    await tester.tap(find.text('この区間に無い番号'));
    expect(taps, 1);
  });

  testWidgets('行き先が無いときは入口を出さない', (tester) async {
    await tester.pumpWidget(_app(SizedBox(
      width: 400,
      height: 500,
      child: BusNumberTable(
        state: TableState.noDestination,
        sortMode: TableSortMode.transfers,
        rows: const [],
        flatEntries: const [],
        isRidingLeg: (_, _) => false,
        onReload: () {},
        onMissingNumber: () {},
        onTap: (_) {},
        onLongPress: (_, _) {},
      ),
    )));
    expect(find.text('この区間に無い番号'), findsNothing);
  });

  testWidgets('両端に停留所がある路線が1本ならその路線を返す', (tester) async {
    int? picked;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          picked = await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SizedBox(
              height: 500,
              child: MissingNumberSheet(routes: [reversed], origin: origin, destination: destination),
            ),
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'e05');
    await tester.tap(find.text('探す'));
    await tester.pumpAndSettle();
    expect(picked, 1);
  });

  testWidgets('両方向とも両端にあれば方面を選ぶ', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () {
          showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SizedBox(
              height: 600,
              child: MissingNumberSheet(
                routes: [reversed, forward],
                origin: origin,
                destination: destination,
              ),
            ),
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'E05');
    await tester.tap(find.text('探す'));
    await tester.pumpAndSettle();
    expect(find.text('Long Biên → Smart City'), findsOneWidget);
    expect(find.text('Smart City → Long Biên'), findsOneWidget);
  });
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ja'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: home),
    );
