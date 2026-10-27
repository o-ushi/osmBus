import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../models/local_itinerary.dart';
import '../state/trip_controller.dart';
import 'bus_number_table.dart';
import 'bus_route_browser_screen.dart';
import 'destination_picker_screen.dart';
import 'help_screen.dart';
import 'keypad.dart';
import 'plan_screen.dart';
import 'result_banner.dart';
import 'route_map_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

/// Swift 版 `MainView` と同じ 2 画面。既定はマトリクス（トップ）、切り替えで番号入力（メイン）。
class TopScreen extends StatefulWidget {
  const TopScreen({super.key, required this.controller});

  final TripController controller;

  @override
  State<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends State<TopScreen> {
  TripController get controller => widget.controller;
  bool _showsTopScreen = true;

  @override
  void initState() {
    super.initState();
    // 画面表示時に位置の許可を求める。
    if (controller.requestsLocationOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.requestLocation());
    }
  }

  void _toggleScreen() => setState(() => _showsTopScreen = !_showsTopScreen);

  bool _showingAlert = false;

  /// 乗車中のアラートを 1 件ずつ出す（Swift の `.alert(item:)` と逆方向の警告）。
  void _showPendingAlert() {
    final alert = controller.pendingAlert;
    if (alert == null || _showingAlert || !mounted) return;
    _showingAlert = true;
    final l10n = AppLocalizations.of(context);
    final (title, body) = switch (alert) {
      DistanceRidingAlert(:final meters) => (l10n.distanceAlertTitle, l10n.distanceAlertBody(meters)),
      WrongDirectionRidingAlert(:final fromRouteMap) =>
        (l10n.wrongDirectionTitle, fromRouteMap ? l10n.wrongDirectionBodyRouteMap : l10n.wrongDirectionBody),
    };
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
        ],
      ),
    ).whenComplete(() {
      _showingAlert = false;
      controller.dismissAlert();
      // 前のアラートが閉じ切ってから次を出す。
      Future<void>.delayed(const Duration(milliseconds: 300), _showPendingAlert);
    });
  }

  /// 距離バッジの長押し。ナビ中止（目的地も消える）。
  Future<void> _confirmCancelNavigation() async {
    if (controller.destination == null && controller.riding == null) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.cancelNavigationConfirm),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancelNavigation),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (ok == true) await controller.cancelNavigation();
  }

  /// 乗車中に距離バッジをタップ。今のルート図を開く。
  void _openRidingMap() {
    final riding = controller.riding;
    if (riding == null) return;
    final itinerary = riding.itinerary;
    if (itinerary != null) {
      _openMap(itinerary);
      return;
    }
    _openRouteBrowser();
  }

  /// メニューの「路線図」。乗車中でも番号で探せる路線図を開く（Swift と同じ）。
  /// 路線図から乗車中なら、その路線を開いた状態にする。
  void _openRouteBrowser() {
    final routeId = controller.riding?.routeId;
    final route = routeId == null
        ? null
        : controller.visibleCatalog.routes.where((r) => r.relationId == routeId).firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BusRouteBrowserScreen(controller: controller, initialRoute: route)),
    );
  }

  /// 地図シートを開く。シートの中でも出発地／目的地を切り替えられる（Swift と同じ）。
  Future<void> _pickOnMap(PickRole role) async {
    final picked = await showDestinationPicker(
      context,
      initialRole: role,
      initialCenter: role == PickRole.origin
          ? controller.origin
          : controller.destination?.point ?? controller.origin,
      searchCenter: controller.origin,
      controller: controller,
    );
    if (picked == null) return;
    switch (picked.role) {
      case PickRole.origin:
        controller.setManualOrigin(picked.place);
      case PickRole.destination:
        await controller.setDestination(picked.place);
    }
  }

  void _openSettings() => showSettingsSheet(context, controller);

  void _openMap(LocalItinerary itinerary) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouteMapScreen(itinerary: itinerary, controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.pendingAlert != null) WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingAlert());
        final distance = controller.distanceLeftMeters;
        final riding = controller.riding;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 140,
            leading: distance != null || riding != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _DistanceBadge(
                        meters: distance,
                        label: l10n.distanceLeft,
                        onTap: riding == null ? null : _openRidingMap,
                        onLongPress: _confirmCancelNavigation,
                      ),
                    ),
                  )
                : null,
            toolbarHeight: 64,
            actions: [
              _MoreMenu(
                showsTopScreen: _showsTopScreen,
                onToggleScreen: _toggleScreen,
                onSettings: _openSettings,
                onRouteMap: _openRouteBrowser,
                onPlan: () => showPlanSheet(context, controller),
                onHelp: () => showHelpSheet(context, controller.plan),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: SceneBackground()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    12,
                    AppTheme.screenPadding,
                    8,
                  ),
                  child: _showsTopScreen ? _topContent(context) : _mainContent(context),
                ),
              ),
              // 左端からの右スワイプだけで画面を切り替える。
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 200) _toggleScreen();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _originDestinationCard() => OriginDestinationCard(
        controller: controller,
        onDestinationTap: () => _pickOnMap(PickRole.destination),
        onOriginTap: () => _pickOnMap(PickRole.origin),
      );

  Widget _topContent(BuildContext context) {
    return Column(
      children: [
        _originDestinationCard(),
        const SizedBox(height: AppTheme.sectionSpacing),
        Expanded(
          child: BusNumberTable(
            state: controller.tableState,
            sortMode: controller.sortMode,
            rows: controller.tableState == TableState.ready ? controller.matrixRows : const [],
            flatEntries:
                controller.tableState == TableState.ready ? controller.flatEntries : const [],
            isRidingLeg: (entry, legIndex) => controller.isRidingLeg(entry.itinerary, legIndex),
            onReload: controller.reload,
            onTap: (entry) => _openMap(entry.itinerary),
            onLongPress: (entry, legIndex) => controller.toggleRiding(entry, legIndex: legIndex),
          ),
        ),
      ],
    );
  }

  Widget _mainContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final available = height - (AppTheme.locationRowHeight * 2 + 1) - AppTheme.sectionSpacing * 2;
        final keypadHeight = (height * 0.48).clamp(200.0, (available - 110).clamp(200.0, double.infinity));
        return Column(
          children: [
            _originDestinationCard(),
            const SizedBox(height: AppTheme.sectionSpacing),
            Expanded(
              child: BusCard(
                child: ResultBanner(
                  decision: controller.decision,
                  input: controller.input,
                  ridingAlightStop: controller.ridingAlightStop,
                  onStartRiding: controller.startRiding,
                  onStopRiding: controller.endRiding,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.sectionSpacing),
            SizedBox(
              height: keypadHeight,
              child: Keypad(
                input: controller.input,
                onDigit: controller.appendDigit,
                onClear: controller.clearInput,
                onSubmit: controller.submitInput,
                onKeyFeedback: controller.sound?.keyTap,
                onEnterFeedback: controller.sound?.enterKey,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 目的地と現在地を 1 枚にまとめたカード。
class OriginDestinationCard extends StatelessWidget {
  const OriginDestinationCard({
    super.key,
    required this.controller,
    required this.onDestinationTap,
    required this.onOriginTap,
  });

  final TripController controller;
  final VoidCallback onDestinationTap;
  final VoidCallback onOriginTap;

  String _locationStatus(AppLocalizations l10n) {
    switch (controller.locationStatus) {
      case LocationStatus.denied || LocationStatus.deniedForever || LocationStatus.serviceDisabled:
        return l10n.locationNotAllowed;
      case LocationStatus.ok || LocationStatus.unknown:
        if (controller.origin != null) return l10n.locationAcquired;
        if (controller.locating) return l10n.locationFetching;
        return l10n.locationNotAcquired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destination = controller.destination;
    final manual = controller.manualOrigin;
    final denied = switch (controller.locationStatus) {
      LocationStatus.denied || LocationStatus.deniedForever || LocationStatus.serviceDisabled => true,
      _ => false,
    };
    const iconSize = 22.0;

    return BusCard(
      child: Column(
        children: [
          SizedBox(
            height: AppTheme.locationRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.destinationLabel,
                    value: destination?.name ?? l10n.destinationUnset,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDestinationTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.cardPaddingH),
                        child: Row(
                          children: [
                            Icon(
                              destination != null
                                  ? CupertinoIcons.location_circle_fill
                                  : CupertinoIcons.map_pin_ellipse,
                              size: iconSize,
                              color: destination != null ? AppTheme.accent : AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                destination?.name ?? l10n.destinationUnset,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: destination != null ? Colors.black : AppTheme.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: const Color(0x40808080),
                ),
                Semantics(
                  button: true,
                  label: l10n.pickOnMap,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDestinationTap,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.cardPaddingH),
                      child: Icon(CupertinoIcons.map, size: iconSize, color: AppTheme.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: AppTheme.cardPaddingH + 10, height: 0.5),
          SizedBox(
            height: AppTheme.locationRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOriginTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppTheme.cardPaddingH),
                      child: Row(
                        children: [
                          Icon(
                            manual != null
                                ? CupertinoIcons.map_pin_ellipse
                                : denied
                                    ? CupertinoIcons.location_slash
                                    : CupertinoIcons.location_fill,
                            size: iconSize,
                            color: manual != null
                                ? AppTheme.verdictGreen
                                : denied
                                    ? Colors.orange
                                    : AppTheme.accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              manual != null
                                  ? l10n.manualOriginLabel(manual.name)
                                  : l10n.currentLocationLabel(_locationStatus(l10n)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (manual != null)
                  IconButton(
                    tooltip: l10n.clearManualOrigin,
                    onPressed: controller.clearManualOrigin,
                    icon: const Icon(CupertinoIcons.xmark_circle, size: iconSize, color: Colors.orange),
                  )
                else if (denied)
                  IconButton(
                    tooltip: l10n.settings,
                    onPressed: Geolocator.openAppSettings,
                    icon: const Icon(CupertinoIcons.gear_alt, size: iconSize, color: AppTheme.accent),
                  )
                else if (controller.locating)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CupertinoActivityIndicator(),
                  )
                else
                  IconButton(
                    tooltip: l10n.reload,
                    onPressed: controller.requestLocation,
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: iconSize, color: AppTheme.accent),
                  ),
                IconButton(
                  tooltip: l10n.pickOriginOnMap,
                  onPressed: onOriginTap,
                  icon: const Icon(CupertinoIcons.map, size: iconSize, color: AppTheme.accent),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ナビゲーションバーの「あと」距離バッジ。
class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.meters, required this.label, this.onTap, this.onLongPress});

  final double? meters;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = meters == null ? null : DistanceColorBand.colors(meters!);
    final textColor = colors?.$2 ?? AppTheme.secondaryText;
    final value = meters == null ? '—' : DistanceColorBand.format(meters!);
    return Semantics(
      label: label,
      value: value,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: colors?.$1 ?? const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
              // 桁が多くても 1 行に収める（バッジの高さは固定）。
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: textColor, height: 1.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右上の「…」メニュー。
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.showsTopScreen,
    required this.onToggleScreen,
    required this.onSettings,
    required this.onRouteMap,
    required this.onPlan,
    required this.onHelp,
  });

  final bool showsTopScreen;
  final VoidCallback onToggleScreen;
  final VoidCallback onSettings;
  final VoidCallback onRouteMap;
  final VoidCallback onPlan;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    PopupMenuItem<VoidCallback> item(IconData icon, String text, VoidCallback action) => PopupMenuItem(
          value: action,
          height: 54,
          child: Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 22),
              const SizedBox(width: 14),
              Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.more,
      icon: const Icon(CupertinoIcons.ellipsis_circle, color: AppTheme.accent, size: 26),
      color: AppTheme.cardFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 240),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        item(
          CupertinoIcons.rectangle_on_rectangle,
          showsTopScreen ? l10n.menuMainScreen : l10n.menuTopScreen,
          onToggleScreen,
        ),
        item(CupertinoIcons.map, l10n.lineMap, onRouteMap),
        const PopupMenuDivider(),
        item(CupertinoIcons.gear_alt, l10n.settings, onSettings),
        item(Icons.workspace_premium_outlined, l10n.planManagement, onPlan),
        item(CupertinoIcons.question_circle, l10n.help, onHelp),
      ],
    );
  }
}
