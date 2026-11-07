import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/ui/bus_map.dart';

void main() {
  testWidgets('地図クレジットは狭い幅でも右にはみ出さない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(body: Center(child: SizedBox(width: 320, height: 240, child: osmAttribution()))),
      ),
    );

    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
