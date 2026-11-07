import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../state/app_settings.dart';
import 'startup_bottom_bar.dart';
import 'swipe_to_close_wrapper.dart';
import 'theme.dart';

/// 起動時（設定で有効なとき）の案内画面。osm日日是好日と同じ構成で、
/// 「次回から表示しない」と「はじめる」は画面下に固定する。
class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.onContinue,
    required this.settings,
  });

  /// [dontShowAgain]がtrueなら、呼び出し側で次回表示オフを保存する。
  final ValueChanged<bool> onContinue;

  final AppSettings settings;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const scene = AppTheme.scene;
    const fg = Colors.white;
    const muted = Colors.white70;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeData.estimateBrightnessForColor(scene) == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scene,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 12, 0),
                  child: _LanguageFlagButton(settings: widget.settings),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 28),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'osmBus',
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: fg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.helpIntro,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              StartupBottomBar(
                dontShowAgain: _dontShowAgain,
                onDontShowAgainChanged: (v) =>
                    setState(() => _dontShowAgain = v),
                dontShowAgainLabel: l10n.startupDontShowAgain,
                label: l10n.startupStart,
                onPressed: () => widget.onContinue(_dontShowAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageFlagButton extends StatelessWidget {
  const _LanguageFlagButton({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final current =
        settings.language ??
        AppLanguage.values.firstWhere(
          (l) => l.code == code,
          orElse: () => AppLanguage.english,
        );
    return PopupMenuButton<AppLanguage>(
      onSelected: settings.setLanguage,
      itemBuilder: (_) => [
        for (final l in AppLanguage.values)
          PopupMenuItem(value: l, child: Text(l.fullLabel)),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(current.flag, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// 設定で有効なら、起動時にスタートアップ画面を出してから [child] を見せる。
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.settings,
    required this.openedByLink,
    required this.child,
  });

  final AppSettings settings;

  /// osmStroll などから目的地付きで呼ばれたら true。設定は変えず、この起動では出さない。
  final ValueListenable<bool> openedByLink;
  final Widget child;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late bool _showing =
      widget.settings.showStartupScreen && !widget.openedByLink.value;

  /// 一度ホームを出したら、スタートアップに戻っても作り直さない
  /// （osm日日是好日の AppRootShell と同じく、表示の切り替えだけで行き来する）。
  late bool _homeBuilt = !_showing;

  @override
  void initState() {
    super.initState();
    widget.openedByLink.addListener(_onLink);
  }

  @override
  void dispose() {
    widget.openedByLink.removeListener(_onLink);
    super.dispose();
  }

  void _onLink() {
    if (widget.openedByLink.value && _showing) {
      setState(() {
        _showing = false;
        _homeBuilt = true;
      });
    }
  }

  /// ホームで左端から右へスワイプしたとき。設定がオンのときだけ戻る。
  void _swipeBackToStartup() {
    if (!widget.settings.showStartupScreen) return;
    setState(() => _showing = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_homeBuilt)
          Positioned.fill(
            child: Offstage(
              offstage: _showing,
              child: TickerMode(
                enabled: !_showing,
                child: SwipeToCloseWrapper(
                  onClose: _swipeBackToStartup,
                  child: widget.child,
                ),
              ),
            ),
          ),
        if (_showing)
          StartupScreen(
            settings: widget.settings,
            onContinue: (dontShowAgain) {
              if (dontShowAgain) widget.settings.setShowStartupScreen(false);
              setState(() {
                _showing = false;
                _homeBuilt = true;
              });
            },
          ),
      ],
    );
  }
}
