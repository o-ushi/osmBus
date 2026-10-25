import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../models/bus_matrix.dart';
import '../services/catalog_sync.dart';
import '../services/route_catalog_downloader.dart';
import '../state/trip_controller.dart';
import 'theme.dart';

/// Swift 版と同じく、設定はシートで出す。
Future<void> showSettingsSheet(BuildContext context, TripController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: SettingsScreen(controller: controller),
    ),
  );
}

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
      listenable: controller,
      builder: (context, _) {
        final consent = controller.consentGranted;
        final catalog = controller.visibleCatalog;
        final downloader = controller.downloader;
        final activity = _activityText(l10n, downloader.activity);
        final canDownload = consent && !downloader.isWorking && controller.origin != null;
        final syncSupported = controller.sync.isSupported;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.settings,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            _Section(
              title: l10n.sectionData,
              children: [
                _Row(
                  title: l10n.consentTitle,
                  subtitle: l10n.consentDescription,
                  trailing: CupertinoSwitch(value: consent, onChanged: controller.setConsent),
                ),
                _Row(
                  title: l10n.routeCount(catalog.routes.length),
                  subtitle: '${l10n.geometryCount(catalog.geometryCount)}\n'
                      '${l10n.lastSaved(_time(context, catalog.syncedAt))}',
                ),
                if (downloader.activity case DownloadWorking(:final done, :final total))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: LinearProgressIndicator(value: total == 0 ? null : done / total),
                  ),
                if (activity != null) _Row(title: activity, muted: true),
                if (consent && controller.origin == null) _Row(title: l10n.needsLocation, destructive: true),
                _Row(
                  title: l10n.downloadAll,
                  action: true,
                  enabled: canDownload,
                  onTap: controller.downloadAll,
                  leading: CupertinoIcons.cloud_download,
                ),
                _Row(
                  title: l10n.updateRoutes,
                  action: true,
                  enabled: canDownload,
                  onTap: controller.updateCatalog,
                  leading: CupertinoIcons.arrow_2_circlepath,
                ),
                if (controller.consentDecided)
                  _Row(
                    title: l10n.withdrawConsent,
                    destructive: true,
                    onTap: () => _withdraw(context),
                    leading: CupertinoIcons.trash,
                  ),
              ],
            ),
            _Section(
              title: l10n.sectionBackup,
              children: [
                _Row(
                  title: l10n.exportBackup,
                  action: true,
                  onTap: controller.exportBackup,
                  leading: CupertinoIcons.square_arrow_up,
                ),
                _Row(
                  title: l10n.importBackup,
                  action: true,
                  onTap: () => _import(context),
                  leading: CupertinoIcons.square_arrow_down,
                ),
              ],
            ),
            _Section(
              title: l10n.sectionArchive,
              children: [
                FutureBuilder<int>(
                  // 保存のたびに数え直す。
                  key: ValueKey(controller.store.version),
                  future: controller.archivedRouteCount(),
                  builder: (context, count) => _Row(title: l10n.archiveCount(count.data ?? 0), muted: true),
                ),
                _Row(
                  title: l10n.archiveRestore,
                  action: true,
                  onTap: () => _restoreArchive(context),
                  leading: CupertinoIcons.arrow_counterclockwise,
                ),
                _Row(
                  title: l10n.archiveExport,
                  action: true,
                  onTap: controller.exportArchive,
                  leading: CupertinoIcons.square_arrow_up,
                ),
              ],
            ),
            _Section(
              title: l10n.sectionSync,
              children: [
                _Row(
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
                  _Row(
                    title: controller.syncing
                        ? l10n.syncing
                        : l10n.lastSynced(_time(context, controller.lastSyncedAt)),
                    subtitle: controller.syncError == null ? null : l10n.syncError(controller.syncError!),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: controller.iCloudEnabled && !controller.syncing ? controller.syncNow : null,
                      child: Text(l10n.syncNow),
                    ),
                  ),
              ],
            ),
            _Section(
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
                  _Row(title: l10n.metricLabel, muted: true),
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
            _Section(
              title: l10n.sectionLocation,
              children: [
                _Row(
                  title: _locationText(l10n, controller.locationStatus),
                  trailing: switch (controller.locationStatus) {
                    LocationStatus.ok => null,
                    LocationStatus.deniedForever => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: Geolocator.openAppSettings,
                        child: Text(l10n.openSettings),
                      ),
                    LocationStatus.serviceDisabled => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: Geolocator.openLocationSettings,
                        child: Text(l10n.openSettings),
                      ),
                    _ => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: controller.requestLocation,
                        child: Text(l10n.retry),
                      ),
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// iOS の inset grouped セクション。
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(indent: 16, height: 0.5),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.action = false,
    this.destructive = false,
    this.muted = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? leading;
  final VoidCallback? onTap;
  final bool action;
  final bool destructive;
  final bool muted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppTheme.tertiaryText
        : destructive
            ? CupertinoColors.destructiveRed
            : action
                ? AppTheme.accent
                : muted
                    ? AppTheme.secondaryText
                    : Colors.black;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 20, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, color: color)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
