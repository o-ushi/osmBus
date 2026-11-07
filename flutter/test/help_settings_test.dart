import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ids = [
    'Dest',
    'Origin',
    'Place',
    'Ride',
    'Number',
    'Table',
    'Distance',
    'LineMap',
    'NoRoute',
    'Missing',
    'Stop',
    'Network',
  ];
  for (final lang in ['ja', 'en', 'vi']) {
    test('$lang: 節の文言があり、手順は 3 つまでで短い', () {
      final arb = jsonDecode(
        File('lib/l10n/app_$lang.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final id in ids) {
        expect(arb['help${id}Title'], isNotNull, reason: id);
        expect(arb['help${id}1'], isNotNull, reason: id);
        expect(arb['help${id}4'], isNull, reason: id);
        for (var i = 1; i <= 3; i++) {
          final text = arb['help$id$i'] as String?;
          if (text != null) {
            expect(text.length, lessThanOrEqualTo(80), reason: text);
          }
        }
      }
      expect(arb['helpTopBody'], isNull);
      expect((arb['helpIntro'] as String).length, lessThanOrEqualTo(80));
    });
  }
}
