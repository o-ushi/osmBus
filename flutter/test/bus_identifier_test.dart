import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/models/bus_identifier.dart';

void main() {
  group('BusIdentifierParts', () {
    test('35 の compactNumber は 35', () {
      expect(BusIdentifierParts.parse('35')!.compactNumber, '35');
    });

    test('05 と 5 は同じ compactNumber', () {
      expect(BusIdentifierParts.parse('05')!.compactNumber, BusIdentifierParts.parse('5')!.compactNumber);
      expect(BusIdentifierParts.parse('05')!.compactNumber, '5');
    });

    test('BRT01 は prefix BRT number 01', () {
      final parts = BusIdentifierParts.parse('BRT01')!;
      expect(parts.prefix, 'BRT');
      expect(parts.number, '01');
      expect(parts.suffix, '');
      expect(BusIdentifierParts.extractTokens('BRT01').single.prefix, 'BRT');
    });

    test('35A と 35B のソートは A が先', () {
      expect(BusIdentifierParts.sortTokens(['35B', '35A']), ['35A', '35B']);
      expect(BusIdentifierParts.sortTokens(['E35', '35A', '9', '35']), ['9', '35', '35A', 'E35']);
    });

    test('05A のバリアントに 5A が入る', () {
      expect(BusIdentifierParts.variants('05A'), containsAll(['05A', '5A']));
      expect(BusIdentifierParts.variants('35'), ['35']);
    });

    test('包含は英数字の境界で判定する', () {
      expect(BusIdentifierParts.containsBusNumber('Tuyến 35A', '35A'), isTrue);
      expect(BusIdentifierParts.containsBusNumber('135A', '35A'), isFalse);
      expect(BusIdentifierParts.containsBusNumber('35a', '35A'), isTrue);
    });

    test('数字 35 は 35 / 35A / E35 に一致し 135 には一致しない', () {
      for (final ref in ['35', '35A', 'E35', '035']) {
        expect(BusIdentifierParts.refMatchesCompactNumber(ref, '35'), isTrue, reason: ref);
      }
      expect(BusIdentifierParts.refMatchesCompactNumber('135', '35'), isFalse);
    });

    test('表示トークン', () {
      expect(BusIdentifierParts.displayTokenForRef('35A'), '35A');
      expect(BusIdentifierParts.displayTokenForRef('Tuyến 35 BRT01X'), 'BRT01X');
      expect(BusIdentifierParts.displayTokenForRef('Express line 12'), '12');
    });

    test('テンキーは数字のみ最大 4 桁', () {
      expect(BusNumberInput.canAppend('1', '123'), isTrue);
      expect(BusNumberInput.canAppend('1', '1234'), isFalse);
      expect(BusNumberInput.canAppend('A', ''), isFalse);
    });
  });
}
