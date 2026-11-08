import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/trip_controller.dart';
import 'bus_route_browser_screen.dart';
import 'route_map_screen.dart';
import 'theme.dart';
import 'osm_page_route.dart';

/// 「あと」距離バッジ。ホームのアプリバーと各地図の左上で同じものを出す。
/// 未乗車で目的地があれば目的地まで、乗車中は降車停留所まで（GPS から直線）。
/// 路線図から目的地なしで乗っているときは「—」。距離も乗車も無ければ何も出さない。
/// ホームでタップすると乗車中の経路地図を開く。地図の上（[onMap]）でタップするとホームへ戻る
/// （乗車中でない路線図から乗車中の地図へ飛び、行き来して抜け出せなくなるのを防ぐ）。長押しでナビ中止。
class TripDistanceBadge extends StatelessWidget {
  const TripDistanceBadge({
    super.key,
    required this.controller,
    this.onMap = false,
  });

  final TripController controller;

  /// 経路地図・路線図の上に出しているか。
  final bool onMap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // 距離アラートの段を変えたら色の境目も変わる。
      listenable: Listenable.merge([controller, controller.settings]),
      builder: (context, _) {
        final distance = controller.distanceLeftMeters;
        final riding = controller.riding;
        if (distance == null && riding == null) return const SizedBox.shrink();
        return DistanceBadge(
          meters: distance,
          alertMeters: [
            for (final slot in controller.settings.distanceSlots) slot.meters,
          ],
          label: AppLocalizations.of(context).distanceLeft,
          onTap: onMap
              ? () => popToHome(context)
              : riding == null
              ? null
              : () => openRidingMap(context, controller),
          onLongPress: () => confirmCancelNavigation(context, controller),
        );
      },
    );
  }
}

/// 地図やシートを全部閉じてホーム（最初の画面）に戻る。
void popToHome(BuildContext context) {
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}

/// 乗車中の経路地図を開く。番号表から乗っていれば経路地図、路線図から乗っていればその路線の路線図。
void openRidingMap(BuildContext context, TripController controller) {
  final itinerary = controller.riding?.itinerary;
  if (controller.riding == null) return;
  if (itinerary != null) {
    Navigator.of(context, rootNavigator: true).push(
      osmPageRoute(
        closeOnSwipeDown: false,
        builder: (_) =>
            RouteMapScreen(itinerary: itinerary, controller: controller),
      ),
    );
    return;
  }
  openRouteBrowser(context, controller);
}

/// メニューの「路線図」。乗車中でも番号で探せる路線図を開く（Swift と同じ）。
/// 路線図から乗車中なら、その路線を開いた状態にする。
void openRouteBrowser(BuildContext context, TripController controller) {
  final routeId = controller.riding?.routeId;
  final route = routeId == null
      ? null
      : controller.visibleCatalog.routes
            .where((r) => r.relationId == routeId)
            .firstOrNull;
  Navigator.of(context, rootNavigator: true).push(
    osmPageRoute(
      closeOnSwipeDown: false,
      builder: (_) =>
          BusRouteBrowserScreen(controller: controller, initialRoute: route),
    ),
  );
}

/// 距離バッジの長押し。ナビ中止（目的地も消える）。
Future<void> confirmCancelNavigation(
  BuildContext context,
  TripController controller,
) async {
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

/// バッジの見た目。色は [DistanceColorBand]（境目は [alertMeters]）。
class DistanceBadge extends StatelessWidget {
  const DistanceBadge({
    super.key,
    required this.meters,
    required this.alertMeters,
    required this.label,
    this.onTap,
    this.onLongPress,
  });

  final double? meters;

  /// 距離アラート 1・2・3 のメートル。
  final List<int> alertMeters;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = meters == null
        ? null
        : DistanceColorBand.colors(meters!, alertMeters);
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              // 桁が多くても 1 行に収める（バッジの高さは固定）。
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 地図の左上（アプリバーの下、セーフエリアの内側）に置く距離バッジ。
class MapDistanceBadge extends StatelessWidget {
  const MapDistanceBadge({super.key, required this.controller});

  final TripController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, top: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: TripDistanceBadge(controller: controller, onMap: true),
          ),
        ),
      ),
    );
  }
}
