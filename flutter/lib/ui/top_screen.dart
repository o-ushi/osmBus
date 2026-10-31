import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../models/local_itinerary.dart';
import '../state/trip_controller.dart';
import 'bus_number_table.dart';
import 'destination_picker_screen.dart';
import 'distance_badge.dart';
import 'help_screen.dart';
import 'keypad.dart';
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
      WrongDirectionRidingAlert(:final fromRouteMap) => (
        l10n.wrongDirectionTitle,
        fromRouteMap ? l10n.wrongDirectionBodyRouteMap : l10n.wrongDirectionBody,
      ),
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

  /// 地図シートを開く。シートの中でも出発地／目的地を切り替えられる（Swift と同じ）。
  Future<void> _pickOnMap(PickRole role) async {
    final picked = await showDestinationPicker(
      context,
      initialRole: role,
      initialCenter: role == PickRole.origin ? controller.origin : controller.destination?.point ?? controller.origin,
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
      MaterialPageRoute(
        builder: (_) => RouteMapScreen(itinerary: itinerary, controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.pendingAlert != null) WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingAlert());
        final hasBadge = controller.distanceLeftMeters != null || controller.riding != null;
        final darkScene = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        return Scaffold(
          backgroundColor: darkScene ? AppTheme.sceneDark : AppTheme.sceneLight,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            // 方眼が暗いときはステータスバーの文字を明るくする。
            systemOverlayStyle: darkScene ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            automaticallyImplyLeading: false,
            leadingWidth: 140,
            leading: hasBadge
                ? Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TripDistanceBadge(controller: controller),
                    ),
                  )
                : null,
            toolbarHeight: 64,
            actions: [
              _MoreMenu(
                showsTopScreen: _showsTopScreen,
                onToggleScreen: _toggleScreen,
                onSettings: _openSettings,
                onRouteMap: () => openRouteBrowser(context, controller),
                onHelp: () => showHelpSheet(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: SceneBackground()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.screenPadding, 12, AppTheme.screenPadding, 8),
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
            flatEntries: controller.tableState == TableState.ready ? controller.flatEntries : const [],
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
    final detail = (destination?.subtitle?.isNotEmpty ?? false) ? destination!.subtitle : null;
    final manual = controller.manualOrigin;
    final denied = switch (controller.locationStatus) {
      LocationStatus.denied || LocationStatus.deniedForever || LocationStatus.serviceDisabled => true,
      _ => false,
    };
    const iconSize = 22.0;

    return BusCard(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTheme.locationRowHeight),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.destinationLabel,
                    value: [destination?.name ?? l10n.destinationUnset, ?detail].join('\n'),
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
                              child: Padding(
                                // 文字が大きい設定でも行が伸びて、2 行目が下の行に重ならないようにする。
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination?.name ?? l10n.destinationUnset,
                                      maxLines: detail == null ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: destination != null ? Colors.black : AppTheme.secondaryText,
                                      ),
                                    ),
                                    // 登録地の名前だけでは中身の場所が分からないので、場所名と住所も出す。
                                    if (detail != null)
                                      Text(
                                        detail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: AppTheme.locationRowHeight - 20, color: const Color(0x40808080)),
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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTheme.locationRowHeight),
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
                            // 手動の出発地は名前だけ出す（緑のピンで出発地と分かる）。読み上げは「出発地: 名前」。
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                manual != null ? manual.name : l10n.currentLocationLabel(_locationStatus(l10n)),
                                semanticsLabel: manual != null ? l10n.manualOriginLabel(manual.name) : null,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                              ),
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
                  const Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator())
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

/// 右上の「…」。中身は osmGradus と同じくアイコンだけを横に並べる。
class _MoreMenu extends StatefulWidget {
  const _MoreMenu({
    required this.showsTopScreen,
    required this.onToggleScreen,
    required this.onSettings,
    required this.onRouteMap,
    required this.onHelp,
  });

  final bool showsTopScreen;
  final VoidCallback onToggleScreen;
  final VoidCallback onSettings;
  final VoidCallback onRouteMap;
  final VoidCallback onHelp;

  @override
  State<_MoreMenu> createState() => _MoreMenuState();
}

class _MoreMenuState extends State<_MoreMenu> {
  final _buttonKey = GlobalKey();

  void _open() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !context.mounted) return;
    final origin = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    const margin = 8.0;
    final width = _MoreIconMenu.width;
    var left = origin.dx + box.size.width - width;
    if (left < margin) left = margin;
    if (left + width > screen.width - margin) left = screen.width - margin - width;
    final top = origin.dy + box.size.height + 6;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) {
        void go(VoidCallback action) {
          Navigator.pop(dialogContext);
          action();
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: _MoreIconMenu(
                showsTopScreen: widget.showsTopScreen,
                onToggleScreen: () => go(widget.onToggleScreen),
                onRouteMap: () => go(widget.onRouteMap),
                onSettings: () => go(widget.onSettings),
                onHelp: () => go(widget.onHelp),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _buttonKey,
      tooltip: AppLocalizations.of(context).more,
      onPressed: _open,
      icon: const Icon(CupertinoIcons.ellipsis_circle, color: AppTheme.accent, size: 26),
    );
  }
}

/// 「…」の中。文字は出さず、長押しと読み上げで名前が分かる。
class _MoreIconMenu extends StatelessWidget {
  const _MoreIconMenu({
    required this.showsTopScreen,
    required this.onToggleScreen,
    required this.onRouteMap,
    required this.onSettings,
    required this.onHelp,
  });

  final bool showsTopScreen;
  final VoidCallback onToggleScreen;
  final VoidCallback onRouteMap;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  static const _count = 4;
  static const _buttonSize = 40.0;
  static const _glyphSize = 26.0;
  static const _gap = 6.0;
  static const _horizontalPadding = 10.0;
  static const _verticalPadding = 8.0;
  static const width = _horizontalPadding * 2 + _count * _buttonSize + (_count - 1) * _gap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (
        CupertinoIcons.rectangle_on_rectangle,
        showsTopScreen ? l10n.menuMainScreen : l10n.menuTopScreen,
        onToggleScreen,
      ),
      (CupertinoIcons.map, l10n.lineMap, onRouteMap),
      (CupertinoIcons.gear_alt, l10n.settings, onSettings),
      (CupertinoIcons.question_circle, l10n.help, onHelp),
    ];
    return Material(
      color: AppTheme.cardFill,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: _verticalPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              _button(entries[i].$1, entries[i].$2, entries[i].$3),
            ],
          ],
        ),
      ),
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Icon(icon, color: AppTheme.accent, size: _glyphSize),
          ),
        ),
      ),
    );
  }
}
