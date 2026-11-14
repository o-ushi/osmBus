import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/ui/theme.dart';

void main() {
  testWidgets('背景は端末の明暗に関係なくファミリー共通の青', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(platformBrightness: brightness),
          child: const SceneBackground(),
        ),
      );
      final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(box.color, const Color(0xFF3D5993));
    }
  });
}
