import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/local_itinerary.dart';
import '../models/route_catalog.dart';
import '../state/trip_controller.dart';
import 'alight_stepper.dart';
import 'bus_map.dart';
import 'distance_badge.dart';
import 'theme.dart';

/// 番号表のタップ先。乗るバスすべての区間と、乗車・乗換・降車の停留所（Swift の `TransitRouteMapView`）。
/// この旅程に乗っている間は、今乗っているバスの区間を橙にし、ほかの区間は目立たない色にする。
/// 乗っていなければ全区間を青。出発地（手動のとき）・目的地・各区間の停留所・現在地も出す。
class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({super.key, required this.itinerary, this.controller});

  final LocalItinerary itinerary;

  /// あれば乗車中のレグを追う。
  final TripController? controller;

  static const Color _inactiveLeg = Color(0xFFB0BEC5);

  /// 降りた停留所と次に乗る停留所が違えば、その間を歩く。
  static bool _walksBetween(ItineraryLeg from, ItineraryLeg to) => from.alightStop.id != to.boardStop.id;

  /// 各区間で通る停留所。カタログの路線の [ItineraryLeg.boardIndex] から [ItineraryLeg.alightIndex] まで。
  List<GeoPoint> _legStops(ItineraryLeg leg) {
    final route = controller?.visibleCatalog.routes.where((r) => r.relationId == leg.relationId).firstOrNull;
    if (route == null || leg.alightIndex >= route.stops.length || leg.boardIndex > leg.alightIndex) return const [];
    return [for (final stop in route.stops.sublist(leg.boardIndex, leg.alightIndex + 1)) stop.point];
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _build(context, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context, controller.ridingLegIndexIn(itinerary)),
    );
  }

  Widget _build(BuildContext context, int? ridingLeg) {
    final l10n = AppLocalizations.of(context);
    // 乗車中に降車停を ＋／− でずらしていれば、今のレグの降車停と線をそれに合わせる。
    final shown = controller?.ridingView(itinerary) ?? itinerary;
    final legs = shown.legs;
    final board = legs.first.boardStop.point;
    final alight = legs.last.alightStop.point;
    final scheme = Theme.of(context).colorScheme;
    final goal = controller?.destination?.point;
    // 出発地のピン（手動の出発地か、ナビ中に固定した出発地）。
    final originPin = controller?.originPin;
    // 経路を引いた出発地（ナビ中は固定）。乗ったあとは乗車停留所まで歩く線は要らない。
    final start = ridingLeg == null ? controller?.origin : null;

    final lines = <MapLine>[
      // 乗っていない区間を先に描き、乗っている区間を上に重ねる。
      for (final (i, leg) in legs.indexed)
        if (ridingLeg != null && i != ridingLeg) MapLine(leg.path, color: _inactiveLeg, width: 4),
      for (final (i, leg) in legs.indexed)
        if (ridingLeg == null || i == ridingLeg)
          MapLine(leg.path, color: ridingLeg == null ? scheme.primary : Colors.orange, width: 6),
      for (var i = 0; i + 1 < legs.length; i++)
        if (_walksBetween(legs[i], legs[i + 1]))
          MapLine(
            [legs[i].alightStop.point, legs[i + 1].boardStop.point],
            color: Colors.grey,
            width: 4,
            dashed: true,
          ),
      // 出発地から乗車停留所まで、最後の降車停留所から目的地まで歩く区間は青の点線。
      if (start != null && start != board) MapLine([start, board], color: walkToFromStopsColor, width: 4, dashed: true),
      if (goal != null && goal != alight) MapLine([alight, goal], color: walkToFromStopsColor, width: 4, dashed: true),
    ];
    final pins = <MapPin>[
      for (final leg in legs)
        for (final stop in _legStops(leg)) MapPin(stop, MapPinStyle.stop),
      for (var i = 0; i + 1 < legs.length; i++)
        if (_walksBetween(legs[i], legs[i + 1])) MapPin(legs[i].alightStop.point, MapPinStyle.stop),
      MapPin(board, MapPinStyle.board),
      for (final leg in legs.skip(1)) MapPin(leg.boardStop.point, MapPinStyle.transfer),
      MapPin(alight, MapPinStyle.alight),
      if (goal != null) MapPin(goal, MapPinStyle.goal),
      if (originPin != null) MapPin(originPin, MapPinStyle.origin),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeMapTitle(legs.map((l) => l.ref).join(' → ')))),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BusMap(
                    initialCenter: board,
                    initialFit: <GeoPoint>[board, alight, ?goal, ?originPin, ?start, for (final leg in legs) ...leg.path],
                    fitPadding: const EdgeInsets.fromLTRB(48, 56, 48, 110),
                    myLocation: controller?.gps,
                    lines: lines,
                    pins: pins,
                  ),
                ),
                if (controller != null) MapDistanceBadge(controller: controller!, onRidingMap: ridingLeg != null),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final (i, leg) in legs.indexed)
                    ListTile(
                      dense: true,
                      // 番号表と同じく、長押しで乗車・乗換・降車。
                      leading: BusBadge(
                        text: leg.ref,
                        riding: i == ridingLeg,
                        onLongPress: controller == null ? null : () => controller!.toggleRidingLeg(itinerary, i),
                        semanticsLabel: '${leg.ref}. ${l10n.routeBoardHint}',
                      ),
                      title: Text(i == 0 ? l10n.boardAt(leg.boardStop.name) : l10n.transferAt(leg.boardStop.name)),
                      subtitle: i == ridingLeg
                          ? AlightStepper(controller: controller!, fallbackStopName: leg.alightStop.name)
                          : Text(l10n.alightAt(leg.alightStop.name)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: Text(
                      controller == null
                          ? l10n.walkMeters(itinerary.walkMeters.round())
                          : '${l10n.walkMeters(itinerary.walkMeters.round())}\n${l10n.routeBoardHint}',
                      style: const TextStyle(color: AppTheme.secondaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
