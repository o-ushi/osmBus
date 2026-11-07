import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osmbus/l10n/app_localizations.dart';
import 'package:osmbus/state/app_settings.dart';
import 'package:osmbus/ui/startup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppSettings> pump(
    WidgetTester tester,
    Map<String, Object> values, {
    ValueListenable<bool>? openedByLink,
  }) async {
    SharedPreferences.setMockInitialValues(values);
    final settings = AppSettings(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StartupGate(
          settings: settings,
          openedByLink: openedByLink ?? ValueNotifier(false),
          child: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('初回はスタートアップが出て、はじめるで先へ進む', (tester) async {
    final settings = await pump(tester, {});
    expect(find.text('home'), findsNothing);
    expect(find.text('はじめる'), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(settings.showStartupScreen, isTrue);
  });

  testWidgets('次回から表示しないを選ぶと保存される', (tester) async {
    final settings = await pump(tester, {});
    await tester.tap(find.text('次回から表示しない'));
    await tester.pump();
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(settings.showStartupScreen, isFalse);
  });

  testWidgets('オフなら最初から先の画面', (tester) async {
    await pump(tester, {'showStartupScreen': false});
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('リンクで起動したらスタートアップを出さず、設定も変えない', (tester) async {
    final settings = await pump(tester, {}, openedByLink: ValueNotifier(true));
    expect(find.text('home'), findsOneWidget);
    expect(settings.showStartupScreen, isTrue);
  });

  testWidgets('スタートアップ表示中にリンクが来たら閉じる', (tester) async {
    final link = ValueNotifier(false);
    final settings = await pump(tester, {}, openedByLink: link);
    expect(find.text('はじめる'), findsOneWidget);
    link.value = true;
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(settings.showStartupScreen, isTrue);
  });
}
