import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/app_log.dart';
import '../state/app_settings.dart';
import '../state/trip_controller.dart';
import 'grouped_list.dart';
import 'sheet_page.dart';
import 'theme.dart';

/// 設定の一番下（バージョン）を続けて押すと開く開発者画面。
/// 端末とアプリの状態、ログの閲覧・送信・消去、アラートと通知の試験。
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key, required this.controller});

  final TripController controller;

  /// 送るログの先頭に付ける端末・アプリの情報。位置は含めない。
  static Future<String> diagnostics(TripController controller) async {
    final buffer = StringBuffer('osmBus diagnostics\n');
    try {
      final info = await PackageInfo.fromPlatform();
      buffer.writeln('app: ${info.packageName} ${info.version} (${info.buildNumber})');
    } catch (_) {}
    final archive = await controller.archivedRouteCount();
    final settings = controller.settings;
    buffer
      ..writeln('os: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('locale: ${Platform.localeName} app=${settings.language?.code ?? 'system'}')
      ..writeln('time: ${DateTime.now().toIso8601String()} (UTC${DateTime.now().timeZoneOffset.isNegative ? '' : '+'}'
          '${DateTime.now().timeZoneOffset.inMinutes / 60})')
      ..writeln('plan: ${controller.plan.plan.name}')
      ..writeln('consent: ${controller.consentGranted}')
      ..writeln('routes: ${controller.visibleCatalog.routes.length} geometry=${controller.visibleCatalog.geometryCount} '
          'archive=$archive')
      ..writeln('location: ${controller.locationStatus.name} fix=${controller.origin != null} '
          'manualOrigin=${controller.manualOrigin != null}')
      ..writeln('destination: ${controller.destination != null}')
      ..writeln('riding: ${controller.riding?.ref ?? '-'}')
      ..writeln('alerts: rings=${settings.activeThresholds} '
          'alarm=${settings.isAlertEnabled(StopAlertMode.alarm)} sound=${settings.alertSoundId} '
          'followsSystem=${settings.alertFollowsSystemVolume} volume=${settings.alertVolume} '
          'vibration=${settings.isAlertEnabled(StopAlertMode.vibration)} alert=${settings.isAlertEnabled(StopAlertMode.alert)}')
      ..writeln('iCloud: enabled=${controller.iCloudEnabled} supported=${controller.sync.isSupported}')
      ..writeln('verboseLog: ${settings.verboseLog}');
    return buffer.toString();
  }

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  TripController get controller => widget.controller;
  String _diagnostics = '';
  int _logBytes = 0;

  @override
  void initState() {
    super.initState();
    AppLog.i('dev', 'developer screen opened');
    _refresh();
  }

  Future<void> _refresh() async {
    final text = await DeveloperScreen.diagnostics(controller);
    await AppLog.instance.flush();
    final bytes = await AppLog.instance.sizeOnDisk();
    if (mounted) {
      setState(() {
        _diagnostics = text;
        _logBytes = bytes;
      });
    }
  }

  /// 共有シート（メール・メッセージ・ファイルなど）でログを送る。
  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;
    try {
      final file = await AppLog.instance.export(await DeveloperScreen.diagnostics(controller));
      AppLog.i('dev', 'log exported ${file.lengthSync()} bytes');
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: l10n.devLogSubject,
        text: l10n.devLogShareText,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (e, st) {
      AppLog.e('dev', 'log export failed', e, st);
      if (mounted) _message(l10n.devLogSendFailed('$e'));
    }
  }

  Future<void> _copy() async {
    final text = [_diagnostics, '---', ...AppLog.instance.recent.map((e) => '$e')].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _message(AppLocalizations.of(context).devLogCopied);
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.devLogClearConfirm),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppLog.instance.clear();
    AppLog.i('dev', 'log cleared');
    await _refresh();
  }

  void _message(String text) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(text),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  /// 実際の到着アラートと同じ鳴らし方（アラーム 3 回・バイブ）を試す。
  void _testAlarm() {
    final settings = controller.settings;
    AppLog.i('dev', 'test alarm');
    unawaited(controller.sound?.playAlarm(3));
    if (settings.isAlertEnabled(StopAlertMode.vibration)) controller.sound?.vibrateAlert();
  }

  /// 5 秒後に通知。その間に画面を消して、裏での通知を確かめる。
  Future<void> _testNotification() async {
    final l10n = AppLocalizations.of(context);
    AppLog.i('dev', 'test notification in 5s');
    await controller.notifier?.requestPermission();
    await Future<void>.delayed(const Duration(seconds: 5));
    await controller.notifier?.show(l10n.distanceAlertTitle, l10n.distanceAlertBody(100));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = controller.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([AppLog.instance, settings]),
      builder: (context, _) {
        final entries = AppLog.instance.recent.reversed.take(200).toList();
        return SheetPage(
          title: l10n.developerScreen,
          trailing: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _refresh,
            child: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          children: [
            GroupedSection(
              title: l10n.devAppInfo,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _diagnostics,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ),
            GroupedSection(
              title: l10n.devLogs,
              footer: l10n.devLogsFooter,
              children: [
                GroupedRow(
                  title: l10n.devLogSend,
                  subtitle: l10n.devLogSize((_logBytes / 1024).ceil(), AppLog.instance.recent.length),
                  leading: CupertinoIcons.square_arrow_up,
                  action: true,
                  onTap: _send,
                ),
                GroupedRow(
                  title: l10n.devLogCopy,
                  leading: CupertinoIcons.doc_on_clipboard,
                  action: true,
                  onTap: _copy,
                ),
                GroupedRow(
                  title: l10n.devVerboseLog,
                  subtitle: l10n.devVerboseLogDetail,
                  trailing: CupertinoSwitch(
                    value: settings.verboseLog,
                    onChanged: (on) {
                      settings.setVerboseLog(on);
                      AppLog.instance.verbose = on;
                      AppLog.i('dev', 'verbose log $on');
                    },
                  ),
                ),
                GroupedRow(
                  title: l10n.devLogClear,
                  leading: CupertinoIcons.trash,
                  destructive: true,
                  onTap: _clear,
                ),
              ],
            ),
            GroupedSection(
              title: l10n.devTests,
              children: [
                GroupedRow(
                  title: l10n.devTestAlarm,
                  leading: CupertinoIcons.bell,
                  action: true,
                  onTap: _testAlarm,
                ),
                GroupedRow(
                  title: l10n.devTestNotification,
                  subtitle: l10n.devTestNotificationDetail,
                  leading: CupertinoIcons.app_badge,
                  action: true,
                  onTap: _testNotification,
                ),
              ],
            ),
            GroupedSection(
              title: l10n.devRecentLogs,
              children: [
                if (entries.isEmpty)
                  GroupedRow(title: l10n.devNoLogs, muted: true)
                else
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        '${_time(entry.time)} ${entry.levelMark} [${entry.category}] ${entry.message}',
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          color: switch (entry.level) {
                            LogLevel.error => CupertinoColors.destructiveRed,
                            LogLevel.warning => Colors.orange.shade800,
                            LogLevel.debug => AppTheme.secondaryText,
                            LogLevel.info => Colors.black87,
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// 設定の一番下のバージョン表示。7 回続けて押すと開発者画面を開く。
class VersionFooter extends StatefulWidget {
  const VersionFooter({super.key, required this.onUnlock});

  final VoidCallback onUnlock;

  static const int tapsToUnlock = 7;

  @override
  State<VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<VersionFooter> {
  String _version = '';
  int _taps = 0;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    }).catchError((_) {});
  }

  void _tap() {
    final now = DateTime.now();
    // 間が空いたら数え直す。
    if (_lastTap == null || now.difference(_lastTap!) > const Duration(seconds: 2)) _taps = 0;
    _lastTap = now;
    _taps++;
    if (_taps >= VersionFooter.tapsToUnlock) {
      _taps = 0;
      HapticFeedback.mediumImpact();
      widget.onUnlock();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = VersionFooter.tapsToUnlock - _taps;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              'osmBus ${_version.isEmpty ? '' : _version}',
              style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
            ),
            if (_taps >= 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.devTapsLeft(left), style: const TextStyle(fontSize: 12, color: AppTheme.tertiaryText)),
              ),
          ],
        ),
      ),
    );
  }
}
