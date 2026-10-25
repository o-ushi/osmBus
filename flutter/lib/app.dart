import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'state/trip_controller.dart';
import 'ui/theme.dart';
import 'ui/top_screen.dart';

class OsmBusApp extends StatefulWidget {
  const OsmBusApp({super.key, required this.controller});

  final TripController controller;

  @override
  State<OsmBusApp> createState() => _OsmBusAppState();
}

class _OsmBusAppState extends State<OsmBusApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Swift 版と同じく、メイン画面はライト固定。
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      locale: null,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 端末の言語が 3 言語のどれでもなければ日本語。
      localeResolutionCallback: (locale, supported) {
        for (final candidate in supported) {
          if (candidate.languageCode == locale?.languageCode) return candidate;
        }
        return const Locale('ja');
      },
      home: TopScreen(controller: widget.controller),
    );
  }
}
