import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'models/deep_link.dart';
import 'services/app_log.dart';
import 'state/trip_controller.dart';
import 'ui/theme.dart';
import 'ui/top_screen.dart';

class OsmBusApp extends StatefulWidget {
  const OsmBusApp({super.key, required this.controller, this.listensDeepLinks = true});

  final TripController controller;

  /// UI テストではプラグインを呼ばない。
  final bool listensDeepLinks;

  @override
  State<OsmBusApp> createState() => _OsmBusAppState();
}

class _OsmBusAppState extends State<OsmBusApp> with WidgetsBindingObserver {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.listensDeepLinks) _listenDeepLinks();
  }

  void _listenDeepLinks() {
    try {
      _links = AppLinks().uriLinkStream.listen(_openLink, onError: (_) {});
    } catch (_) {}
  }

  void _openLink(Uri uri) {
    final destination = OsmBusDeepLink.parseDestination(uri);
    AppLog.i('link', 'open ${uri.scheme}://${uri.host} valid=${destination != null}');
    if (destination != null) unawaited(widget.controller.setDestination(destination));
  }

  @override
  void dispose() {
    _links?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.controller.onResumed();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        widget.controller.onPaused();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final language = settings.language;
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          // Swift 版と同じく、メイン画面はライト固定。
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          // 設定で選んだ言語。未選択なら端末の言語。
          locale: language == null ? null : Locale(language.code),
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
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            widget.controller.texts = RidingTexts(
              distanceTitle: l10n.distanceAlertTitle,
              distanceBody: l10n.distanceAlertBody,
              wrongDirectionTitle: l10n.wrongDirectionTitle,
              wrongDirectionBody: l10n.wrongDirectionBody,
              trackingTitle: l10n.appTitle,
              trackingBody: l10n.trackingNotice,
            );
            return child!;
          },
          home: TopScreen(controller: widget.controller),
        );
      },
    );
  }
}
