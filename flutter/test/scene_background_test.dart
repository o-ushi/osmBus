import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/ui/theme.dart';

void main() {
  testWidgets('方眼は端末がライトのときクリームの地色になる', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const MaterialApp(home: SceneBackground()));

    expect(_sceneColor(tester), AppTheme.sceneLight);
  });

  testWidgets('方眼は端末がダークのとき暗い地色になる', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const MaterialApp(home: SceneBackground()));

    expect(_sceneColor(tester), AppTheme.sceneDark);
  });
}

Color _sceneColor(WidgetTester tester) {
  final finder = find.descendant(of: find.byType(SceneBackground), matching: find.byType(ColoredBox));
  return tester.widget<ColoredBox>(finder).color;
}
