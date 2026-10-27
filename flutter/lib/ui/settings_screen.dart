import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../models/bus_matrix.dart';
import '../services/catalog_sync.dart';
import '../services/google_maps_config.dart';
import '../services/route_catalog_downloader.dart';
import '../services/sound_player.dart';
import '../state/app_settings.dart';
import '../state/trip_controller.dart';
import 'alert_settings_screen.dart';
import 'developer_screen.dart';
import 'grouped_list.dart';
import 'privacy_screen.dart';
import 'sheet_page.dart';
import 'theme.dart';

/// Swift 版と同じく、設定はシートで出す。到着アラートなどはシートの中で進む。
Future<void> showSettingsSheet(BuildContext context, TripController controller) =>
    showSheetNavigator<void>(context, (_) => SettingsScreen(controller: controller));

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final TripController controller;

  String _time(BuildContext context, DateTime? time) {
    if (time == null) return AppLocalizations.of(context).never;
    final local = time.toLocal();
    final m = MaterialLocalizations.of(context);
    return '${m.formatShortDate(local)} '
        '${m.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
  }

  String? _activityText(AppLocalizations l10n, DownloadActivity activity) => switch (activity) {
        DownloadIdle() => null,
        DownloadWorking(:final done, :final total) => l10n.progress(done, total),
        DownloadFinished(:final geometryCount, :final isUpdate) =>
          isUpdate ? l10n.updateFinished(geometryCount) : l10n.downloadFinished(geometryCount),
        DownloadFailed(:final reason, :final detail) => switch (reason) {
            DownloadFailure.consentRequired => l10n.downloadConsentRequired,
            DownloadFailure.noRoutesNearby => l10n.downloadNoRoutes,
            DownloadFailure.network => l10n.downloadFailed(detail ?? ''),
          },
      };

  String _locationText(AppLocalizations l10n, LocationStatus status) => switch (status) {
        LocationStatus.unknown => l10n.locationUnknown,
        LocationStatus.ok => l10n.locationOk,
        LocationStatus.denied => l10n.locationDenied,
        LocationStatus.deniedForever => l10n.locationDeniedForever,
        LocationStatus.serviceDisabled => l10n.locationServiceDisabled,
      };

  Future<void> _withdraw(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(l10n.withdrawConfirm),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (ok == true) await controller.withdrawConsent();
  }

  Future<void> _import(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final mode = await showCupertinoModalPopup<ImportMode>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.importChooseMode),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImportMode.merge),
            child: Text(l10n.importMerge),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImportMode.replace),
            child: Text(l10n.importReplace),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (mode == null) return;
    final result = await controller.importBackup(mode);
    if (result.isCancelled || !context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(result.error != null ? l10n.importFailed(result.error!) : l10n.importDone(result.routeCount)),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
        ],
      ),
    );
  }

  Future<void> _restoreArchive(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await controller.restoreFromArchive();
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(l10n.importDone(result.routeCount)),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.settings]),
      builder: (context, _) {
        final settings = controller.settings;
        final consent = controller.consentGranted;
        final catalog = controller.visibleCatalog;
        final downloader = controller.downloader;
        final activity = _activityText(l10n, downloader.activity);
        final canDownload = consent && !downloader.isWorking && controller.origin != null;
        final syncSupported = controller.sync.isSupported;

        return SheetPage(
          title: l10n.settings,
          closesSheet: true,
          children: [
            GroupedSection(
              title: l10n.language,
              footer: l10n.languageFooter,
              children: [
                GroupedChoiceRow(
                  title: l10n.languageSystem,
                  selected: settings.language == null,
                  onTap: () => settings.setLanguage(null),
                ),
                for (final language in AppLanguage.values)
                  GroupedChoiceRow(
                    title: language.fullLabel,
                    selected: settings.language == language,
                    onTap: () => settings.setLanguage(language),
                  ),
              ],
            ),
            GroupedSection(
              title: l10n.arrivalAlerts,
              children: [
                GroupedLinkRow(
                  title: l10n.arrivalAlerts,
                  leading: CupertinoIcons.bell,
                  onTap: () => SheetPage.push<void>(context, (_) => AlertSettingsScreen(controller: controller)),
                ),
              ],
            ),
            GroupedSection(
              title: l10n.sectionTable,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CupertinoSlidingSegmentedControl<TableSortMode>(
                    groupValue: controller.sortMode,
                    onValueChanged: (mode) {
                      if (mode != null) controller.setSortMode(mode);
                    },
                    children: {
                      TableSortMode.direction: Text(l10n.sortDirection),
                      TableSortMode.distance: Text(l10n.sortDistance),
                      TableSortMode.transfers: Text(l10n.sortTransfers),
                    },
                  ),
                ),
                if (controller.sortMode == TableSortMode.distance) ...[
                  GroupedRow(title: l10n.metricLabel, muted: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: CupertinoSlidingSegmentedControl<DistanceMetric>(
                      groupValue: controller.distanceMetric,
                      onValueChanged: (metric) {
                        if (metric != null) controller.setDistanceMetric(metric);
                      },
                      children: {
                        DistanceMetric.walkFirst: Text(l10n.metricWalk),
                        DistanceMetric.total: Text(l10n.metricTotal),
                      },
                    ),
                  ),
                ],
              ],
            ),
            _KeyFeedbackSection(controller: controller),
            GroupedSection(
              title: l10n.keypadInput,
              footer: l10n.keypadInputFooter,
              children: [
                GroupedChoiceRow(
                  title: l10n.keypadClearBeforeNew,
                  selected: settings.keypadInputMode == KeypadInputMode.clearBeforeNewInput,
                  onTap: () => settings.setKeypadInputMode(KeypadInputMode.clearBeforeNewInput),
                ),
                GroupedChoiceRow(
                  title: l10n.keypadAppend,
                  selected: settings.keypadInputMode == KeypadInputMode.appendToExisting,
                  onTap: () => settings.setKeypadInputMode(KeypadInputMode.appendToExisting),
                ),
              ],
            ),
            const _MapSection(),
            GroupedSection(
              title: l10n.sectionData,
              children: [
                GroupedRow(
                  title: l10n.consentTitle,
                  subtitle: l10n.consentDescription,
                  trailing: CupertinoSwitch(value: consent, onChanged: controller.setConsent),
                ),
                GroupedRow(
                  title: l10n.routeCount(catalog.routes.length),
                  subtitle: '${l10n.geometryCount(catalog.geometryCount)}\n'
                      '${l10n.lastSaved(_time(context, catalog.syncedAt))}',
                ),
                if (downloader.activity case DownloadWorking(:final done, :final total))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: LinearProgressIndicator(value: total == 0 ? null : done / total),
                  ),
                if (activity != null) GroupedRow(title: activity, muted: true),
                if (consent && controller.origin == null) GroupedRow(title: l10n.needsLocation, destructive: true),
                GroupedRow(
                  title: l10n.downloadAll,
                  action: true,
                  enabled: canDownload,
                  onTap: controller.downloadAll,
                  leading: CupertinoIcons.cloud_download,
                ),
                GroupedRow(
                  title: l10n.updateRoutes,
                  action: true,
                  enabled: canDownload,
                  onTap: controller.updateCatalog,
                  leading: CupertinoIcons.arrow_2_circlepath,
                ),
                if (controller.consentDecided)
                  GroupedRow(
                    title: l10n.withdrawConsent,
                    destructive: true,
                    onTap: () => _withdraw(context),
                    leading: CupertinoIcons.trash,
                  ),
              ],
            ),
            GroupedSection(
              title: l10n.sectionSync,
              children: [
                GroupedRow(
                  title: l10n.iCloudSync,
                  subtitle: syncSupported
                      ? null
                      : controller.sync.unavailableReason == SyncUnavailableReason.notIOS
                          ? l10n.iCloudOnlyIOS
                          : l10n.iCloudUnavailable,
                  trailing: CupertinoSwitch(
                    value: controller.iCloudEnabled,
                    onChanged: syncSupported ? controller.setICloudEnabled : null,
                  ),
                ),
                if (syncSupported)
                  GroupedRow(
                    title: controller.syncing
                        ? l10n.syncing
                        : l10n.lastSynced(_time(context, controller.lastSyncedAt)),
                    subtitle: controller.syncError == null ? null : l10n.syncError(controller.syncError!),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: controller.iCloudEnabled && !controller.syncing ? controller.syncNow : null,
                      child: Semantics(label: l10n.syncNow, child: const Icon(CupertinoIcons.arrow_2_circlepath)),
                    ),
                  ),
              ],
            ),
            GroupedSection(
              title: l10n.sectionBackup,
              children: [
                GroupedRow(
                  title: l10n.exportBackup,
                  action: true,
                  onTap: controller.exportBackup,
                  leading: CupertinoIcons.square_arrow_up,
                ),
                GroupedRow(
                  title: l10n.importBackup,
                  action: true,
                  onTap: () => _import(context),
                  leading: CupertinoIcons.square_arrow_down,
                ),
              ],
            ),
            GroupedSection(
              title: l10n.sectionArchive,
              children: [
                FutureBuilder<int>(
                  // 保存のたびに数え直す。
                  key: ValueKey(controller.store.version),
                  future: controller.archivedRouteCount(),
                  builder: (context, count) => GroupedRow(title: l10n.archiveCount(count.data ?? 0), muted: true),
                ),
                GroupedRow(
                  title: l10n.archiveRestore,
                  action: true,
                  onTap: () => _restoreArchive(context),
                  leading: CupertinoIcons.arrow_counterclockwise,
                ),
                GroupedRow(
                  title: l10n.archiveExport,
                  action: true,
                  onTap: controller.exportArchive,
                  leading: CupertinoIcons.square_arrow_up,
                ),
              ],
            ),
            GroupedSection(
              title: l10n.sectionLocation,
              children: [
                GroupedRow(
                  title: _locationText(l10n, controller.locationStatus),
                  trailing: switch (controller.locationStatus) {
                    LocationStatus.ok => null,
                    LocationStatus.deniedForever => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: Geolocator.openAppSettings,
                        child: Semantics(label: l10n.openSettings, child: const Icon(CupertinoIcons.gear)),
                      ),
                    LocationStatus.serviceDisabled => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: Geolocator.openLocationSettings,
                        child: Semantics(label: l10n.openSettings, child: const Icon(CupertinoIcons.gear)),
                      ),
                    _ => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: controller.requestLocation,
                        child: Semantics(label: l10n.retry, child: const Icon(CupertinoIcons.arrow_clockwise)),
                      ),
                  },
                ),
              ],
            ),
            GroupedSection(
              footer: l10n.privacyFooter,
              children: [
                GroupedLinkRow(
                  title: l10n.privacyTitle,
                  leading: CupertinoIcons.hand_raised_fill,
                  onTap: () => SheetPage.push<void>(context, (_) => PrivacyScreen(controller: controller)),
                ),
              ],
            ),
            VersionFooter(
              onUnlock: () => SheetPage.push<void>(context, (_) => DeveloperScreen(controller: controller)),
            ),
          ],
        );
      },
    );
  }
}

/// キーパッドのフィードバック（Swift の設定「キーパッドのフィードバック」）。
class _KeyFeedbackSection extends StatelessWidget {
  const _KeyFeedbackSection({required this.controller});

  final TripController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = controller.settings;
    return GroupedSection(
      title: l10n.keyFeedback,
      footer: l10n.keyFeedbackFooter,
      children: [
        GroupedRow(
          title: l10n.keyFeedbackHaptic,
          trailing: CupertinoSwitch(
            value: settings.hapticEnabled,
            onChanged: (on) {
              settings.setHapticEnabled(on);
              if (on) SoundPlayer.haptic(settings.hapticStrength);
            },
          ),
        ),
        if (settings.hapticEnabled)
          StrengthPicker(
            title: l10n.keyFeedbackHapticStrength,
            value: settings.hapticStrength,
            onChanged: (strength) {
              settings.setHapticStrength(strength);
              SoundPlayer.haptic(strength);
            },
          ),
        GroupedRow(
          title: l10n.keyFeedbackClick,
          trailing: CupertinoSwitch(
            value: settings.clickEnabled,
            onChanged: (on) {
              settings.setClickEnabled(on);
              if (on) controller.sound?.previewClick(settings.clickVolume);
            },
          ),
        ),
        if (settings.clickEnabled)
          VolumeSlider(
            title: l10n.volume,
            value: settings.clickVolume,
            min: 0,
            onChanged: settings.setClickVolume,
            onChangeEnd: (v) => controller.sound?.previewClick(v),
          ),
      ],
    );
  }
}

/// 弱め・普通・強め。
class StrengthPicker extends StatelessWidget {
  const StrengthPicker({super.key, required this.title, required this.value, required this.onChanged});

  final String title;
  final FeedbackStrength value;
  final ValueChanged<FeedbackStrength> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<FeedbackStrength>(
              groupValue: value,
              onValueChanged: (v) {
                if (v != null) onChanged(v);
              },
              children: {
                FeedbackStrength.light: Text(l10n.strengthLight),
                FeedbackStrength.medium: Text(l10n.strengthMedium),
                FeedbackStrength.heavy: Text(l10n.strengthHeavy),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 音量（%表示つき）。
class VolumeSlider extends StatelessWidget {
  const VolumeSlider({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0.05,
  });

  final String title;
  final double value;
  final double min;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 17)),
              const Spacer(),
              Text('${(value * 100).round()}%', style: const TextStyle(fontSize: 17, color: AppTheme.secondaryText)),
            ],
          ),
          CupertinoSlider(
            value: value.clamp(min, 1.0),
            min: min,
            divisions: ((1 - min) / 0.05).round(),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

/// 地図の背景を Google マップにするか。キーは iOS だけここで変えられる（Swift 版の API キー設定）。
class _MapSection extends StatelessWidget {
  const _MapSection();

  GoogleMapsConfig get config => GoogleMapsConfig.instance;

  String _keyText(AppLocalizations l10n) {
    final user = config.userKey;
    if (user != null) return l10n.mapsKeyUser(user.substring(user.length < 4 ? 0 : user.length - 4));
    return config.hasBundledKey ? l10n.mapsKeyBundled : l10n.mapsKeyNone;
  }

  Future<void> _editKey(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController(text: config.userKey ?? '');
    final key = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.mapsApiKey),
        content: Column(
          children: [
            Text(l10n.mapsKeyDialogMessage),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: field,
              placeholder: 'AIza…',
              autocorrect: false,
              enableSuggestions: false,
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    field.dispose();
    if (key != null) await config.setUserKey(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: config,
      builder: (context, _) => GroupedSection(
        title: l10n.sectionMap,
        footer: Platform.isAndroid ? '${l10n.mapsFooter}\n${l10n.mapsFooterAndroid}' : l10n.mapsFooter,
        children: [
          GroupedRow(
            title: l10n.useGoogleMaps,
            leading: CupertinoIcons.map,
            trailing: CupertinoSwitch(
              value: config.useGoogle,
              onChanged: config.configuredKey == null ? null : config.setEnabled,
            ),
          ),
          GroupedRow(
            title: l10n.mapsApiKey,
            subtitle: config.needsRestart ? '${_keyText(l10n)}\n${l10n.mapsKeyRestart}' : _keyText(l10n),
            leading: CupertinoIcons.lock,
            onTap: config.canEditKey ? () => _editKey(context) : null,
          ),
        ],
      ),
    );
  }
}
