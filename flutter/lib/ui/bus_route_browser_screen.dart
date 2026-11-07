import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/bus_identifier.dart';
import '../models/route_catalog.dart';
import '../models/route_search.dart';
import '../services/geo.dart';
import '../services/local_planner.dart';
import '../state/trip_controller.dart';
import 'alight_stepper.dart';
import 'bus_map.dart';
import 'distance_badge.dart';
import 'keypad.dart';
import 'stop_order_editor.dart';
import 'theme.dart';

/// メニューの「路線図」（Swift の `BusRouteMapView`）。番号で路線を探して地図に出し、
/// 番号バッジの長押しで乗車・降車する。路線は端末内の路線データから探す。
class BusRouteBrowserScreen extends StatefulWidget {
  const BusRouteBrowserScreen({
    super.key,
    required this.controller,
    this.initialRoute,
  });

  final TripController controller;

  /// 路線図から乗車中なら、その路線を開いた状態で始める。
  final RouteRecord? initialRoute;

  @override
  State<BusRouteBrowserScreen> createState() => _BusRouteBrowserScreenState();
}

class _BusRouteBrowserScreenState extends State<BusRouteBrowserScreen> {
  TripController get controller => widget.controller;
  final BusMapController _map = BusMapController();
  late RouteRecord? _route = widget.initialRoute;
  String _input = '';
  bool _clearsOnNextInput = false;
  late bool _keypadVisible = widget.initialRoute == null;

  bool get _riding =>
      _route != null && controller.riding?.routeId == _route!.relationId;

  void _digit(String digit) {
    setState(() {
      if (_clearsOnNextInput) {
        _input = '';
        _clearsOnNextInput = false;
      }
      if (BusNumberInput.canAppend(digit, _input)) _input += digit;
    });
  }

  void _clear() {
    setState(() {
      _clearsOnNextInput = false;
      if (_input.isEmpty) {
        _endRidingIfNeeded();
        _route = null;
      }
      _input = '';
    });
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    _clearsOnNextInput = true;
    final found = RouteSearch.find(
      controller.visibleCatalog.routes,
      _input,
      near: controller.origin,
    );
    if (found.isEmpty) {
      await _error(l10n.routeSearchNone(_input));
      return;
    }
    if (found.length == 1) {
      _open(found.single);
      return;
    }
    final picked = await _pickFrom(
      l10n.routeCandidates,
      l10n.routeCandidatesHint,
      found,
    );
    if (picked != null) _open(picked);
  }

  void _open(RouteRecord route) {
    _endRidingIfNeeded();
    setState(() {
      _route = route;
      _keypadVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(route));
  }

  void _fit(RouteRecord route) => _map.fit(_routePoints(route));

  /// 経路地図と同じく、出発地から乗る停留所までと、降りる停留所から目的地までを歩く。
  /// 乗る・降りる停留所は番号表と同じ選び方（[LocalPlanner]）。この路線で着けなければ、
  /// 出発地・目的地それぞれに一番近い停留所。乗ったあとは乗る停留所まで歩く線は出さない。
  List<MapLine> _walkLines(RouteRecord route, GeoPoint? start, GeoPoint? goal) {
    if (route.stops.isEmpty || (start == null && goal == null)) return const [];
    final leg = start == null || goal == null
        ? null
        : LocalPlanner.plan([route], start, goal).firstOrNull?.firstLeg;
    GeoPoint nearest(GeoPoint p) => route.stops
        .map((s) => s.point)
        .reduce((a, b) => Geo.distance(p, a) <= Geo.distance(p, b) ? a : b);
    final board = start == null || _riding
        ? null
        : leg?.boardStop.point ?? nearest(start);
    final riding = controller.riding;
    // 乗車中に降車停を選び直していれば、そこから歩く。
    final chosen = _riding && riding != null && riding.alightAdjusted
        ? riding.alightStop.point
        : null;
    final alight = goal == null
        ? null
        : chosen ?? leg?.alightStop.point ?? nearest(goal);
    return [
      if (start != null && board != null && board != start)
        MapLine(
          [start, board],
          color: walkToFromStopsColor,
          width: 4,
          dashed: true,
        ),
      if (goal != null && alight != null && alight != goal)
        MapLine(
          [alight, goal],
          color: walkToFromStopsColor,
          width: 4,
          dashed: true,
        ),
    ];
  }

  static List<GeoPoint> _routePoints(RouteRecord route) => [
    for (final s in route.polylineSegments) ...s,
    ...route.stops.map((s) => s.point),
  ];

  /// 乗車中に別の操作（別の番号・クリア・一覧）をしたら降車する（Swift と同じ）。
  void _endRidingIfNeeded() {
    if (_riding) controller.endRiding();
  }

  void _toggleRiding() {
    final opened = _route;
    if (opened == null) return;
    // ユーザーが直した停留所があれば、その並びで乗る。
    final route =
        controller.visibleCatalog.routes
            .where((r) => r.relationId == opened.relationId)
            .firstOrNull ??
        opened;
    if (_riding) {
      controller.endRiding();
    } else {
      controller.startRidingRoute(route);
    }
    setState(() {});
  }

  Future<void> _error(String message) => showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(AppLocalizations.of(context).routeMapErrorTitle),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).ok),
        ),
      ],
    ),
  );

  Future<RouteRecord?> _pickFrom(
    String title,
    String? hint,
    List<RouteRecord> routes,
  ) {
    return showModalBottomSheet<RouteRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.groupedBackground,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: routes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 1),
                itemBuilder: (context, index) {
                  final r = routes[index];
                  final label = r.directionText;
                  return Material(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        r.ref,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: label == null
                          ? null
                          : Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => Navigator.pop(context, r),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openList() async {
    final l10n = AppLocalizations.of(context);
    final routes = RouteSearch.listing(controller.visibleCatalog.routes);
    if (routes.isEmpty) {
      await _error('${l10n.routeListEmpty}\n${l10n.routeListEmptyDetail}');
      return;
    }
    final picked = await _pickFrom(l10n.routeList, null, routes);
    if (picked != null) _open(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // 停留所を直した・OSM の並びに戻したら、同じ路線の今の並びを使う。
        final opened = _route;
        final route = opened == null
            ? null
            : controller.visibleCatalog.routes
                      .where((r) => r.relationId == opened.relationId)
                      .firstOrNull ??
                  opened;
        final origin = controller.origin;
        final originPin = controller.originPin;
        final ridingPath = _riding && controller.riding!.alightAdjusted
            ? controller.riding!.path
            : null;
        final goal = controller.destination?.point;
        return Scaffold(
          backgroundColor: AppTheme.scene,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.scene,
            title: Text(l10n.lineMap),
            actions: [
              if (route != null)
                Semantics(
                  label: route.ref,
                  hint: l10n.routeBoardHint,
                  child: GestureDetector(
                    onLongPress: _toggleRiding,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: BusBadge(text: route.ref, riding: _riding),
                    ),
                  ),
                ),
              if (route != null)
                IconButton(
                  tooltip: l10n.clear,
                  onPressed: () => setState(() {
                    _endRidingIfNeeded();
                    _route = null;
                  }),
                  icon: const Icon(CupertinoIcons.trash),
                ),
              if (controller.consentGranted)
                IconButton(
                  tooltip: l10n.routeList,
                  onPressed: _openList,
                  icon: const Icon(CupertinoIcons.list_bullet),
                ),
              IconButton(
                tooltip: _keypadVisible ? l10n.hideKeypad : l10n.showKeypad,
                onPressed: () =>
                    setState(() => _keypadVisible = !_keypadVisible),
                icon: Icon(
                  _keypadVisible ? Icons.keyboard_hide : Icons.keyboard,
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              BusMap(
                controller: _map,
                initialCenter: origin ?? const GeoPoint(21.0285, 105.8542),
                initialFit: route == null ? null : _routePoints(route),
                fitPadding: const EdgeInsets.fromLTRB(40, 40, 40, 120),
                overlayInsets: EdgeInsets.only(
                  bottom: _overlayBottom(context, route),
                ),
                myLocation: controller.gps,
                lines: [
                  if (route != null)
                    for (final segment in route.polylineSegments)
                      MapLine(
                        segment,
                        color: _riding && ridingPath == null
                            ? Colors.orange
                            : AppTheme.accent,
                      ),
                  // 降車停を選び直したら、乗る区間（乗車停留所から降車停まで）を橙で重ねる。
                  if (ridingPath != null)
                    MapLine(ridingPath, color: Colors.orange, width: 6),
                  if (route != null) ..._walkLines(route, origin, goal),
                ],
                pins: [
                  if (route != null) ...[
                    for (final stop in route.stops)
                      MapPin(stop.point, MapPinStyle.stop),
                    MapPin(route.stops.last.point, MapPinStyle.terminal),
                    if (_riding && controller.riding != null)
                      MapPin(
                        controller.riding!.alightStop.point,
                        MapPinStyle.alight,
                      ),
                  ],
                  if (goal != null) MapPin(goal, MapPinStyle.goal),
                  // GPS は動く現在地の丸。経路を引いた出発地（手動、またはナビ中に固定）は別のピン。
                  if (originPin != null) MapPin(originPin, MapPinStyle.origin),
                ],
              ),
              MapDistanceBadge(controller: controller, onRidingMap: _riding),
              if (route == null && !_keypadVisible)
                _emptyState(l10n, origin == null),
              if (route != null && !_keypadVisible)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 34,
                  child: _routeInfo(l10n, route),
                ),
              if (_keypadVisible)
                Positioned(
                  left: AppTheme.screenPadding,
                  right: AppTheme.screenPadding,
                  bottom: 24,
                  height: MediaQuery.sizeOf(context).height * 0.42,
                  child: Keypad(
                    input: _input,
                    onDigit: _digit,
                    onClear: _clear,
                    onSubmit: _search,
                    onKeyFeedback: controller.sound?.keyTap,
                    onEnterFeedback: controller.sound?.enterKey,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 地図の下を隠すキーパッド・路線の情報の高さ。
  double _overlayBottom(BuildContext context, RouteRecord? route) {
    if (_keypadVisible) return MediaQuery.sizeOf(context).height * 0.42 + 24;
    if (route == null) return 0;
    // 「この路線を確認」の行の分も空ける。
    return _riding ? 178 : 128;
  }

  Widget _emptyState(AppLocalizations l10n, bool noLocation) => Center(
    child: Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.bus,
            size: 36,
            color: AppTheme.secondaryText,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.routeMapEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.secondaryText),
          ),
          if (noLocation) ...[
            const SizedBox(height: 8),
            Text(
              l10n.routeMapNoLocation,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _routeInfo(AppLocalizations l10n, RouteRecord route) {
    final label = route.directionText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.ref,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (label != null)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                Text(
                  _riding ? l10n.ridingLabel : l10n.routeBoardHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: _riding ? Colors.orange : AppTheme.tertiaryText,
                  ),
                ),
                if (_riding)
                  AlightStepper(
                    controller: controller,
                    style: const TextStyle(fontSize: 13),
                  ),
                // 乗車中でなくても、開いている路線の停留所順を自分で直せる。
                StopOrderEditRow(
                  controller: controller,
                  relationId: route.relationId,
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.bus, size: 16, color: AppTheme.accent),
          const SizedBox(width: 2),
          Text(
            '${route.stops.length}',
            style: const TextStyle(fontSize: 12, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}
