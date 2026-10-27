import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/route_catalog.dart';
import '../models/route_search.dart';
import '../state/trip_controller.dart';
import 'bus_map.dart';
import 'keypad.dart';
import 'theme.dart';

/// メニューの「路線図」（Swift の `BusRouteMapView`）。番号で路線を探して地図に出し、
/// 番号バッジの長押しで乗車・降車する。路線は端末内の路線データから探す。
class BusRouteBrowserScreen extends StatefulWidget {
  const BusRouteBrowserScreen({super.key, required this.controller, this.initialRoute});

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

  bool get _riding => _route != null && controller.riding?.routeId == _route!.relationId;

  void _digit(String digit) {
    setState(() {
      if (_clearsOnNextInput) {
        _input = '';
        _clearsOnNextInput = false;
      }
      if (_input.length < 4) _input += digit;
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
    final found = RouteSearch.find(controller.visibleCatalog.routes, _input, near: controller.origin);
    if (found.isEmpty) {
      await _error(l10n.routeSearchNone(_input));
      return;
    }
    if (found.length == 1) {
      _open(found.single);
      return;
    }
    final picked = await _pickFrom(l10n.routeCandidates, l10n.routeCandidatesHint, found);
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

  static List<GeoPoint> _routePoints(RouteRecord route) =>
      [for (final s in route.polylineSegments) ...s, ...route.stops.map((s) => s.point)];

  /// 乗車中に別の操作（別の番号・クリア・一覧）をしたら降車する（Swift と同じ）。
  void _endRidingIfNeeded() {
    if (_riding) controller.endRiding();
  }

  void _toggleRiding() {
    final route = _route;
    if (route == null) return;
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

  Future<RouteRecord?> _pickFrom(String title, String? hint, List<RouteRecord> routes) {
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
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(hint, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: routes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 1),
                itemBuilder: (context, index) {
                  final r = routes[index];
                  final label = _directionLabel(r);
                  return Material(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(r.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: label == null ? null : Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  static String? _directionLabel(RouteRecord r) {
    if (r.from != null && r.to != null) return '${r.from} → ${r.to}';
    return r.name.isNotEmpty && r.name != r.ref ? r.name : null;
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
        final route = _route;
        final origin = controller.origin;
        return Scaffold(
          backgroundColor: AppTheme.sceneLight,
          appBar: AppBar(
            backgroundColor: AppTheme.sceneLight,
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
                onPressed: () => setState(() => _keypadVisible = !_keypadVisible),
                icon: Icon(_keypadVisible ? Icons.keyboard_hide : Icons.keyboard),
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
                overlayInsets: EdgeInsets.only(bottom: _overlayBottom(context, route)),
                lines: [
                  if (route != null)
                    for (final segment in route.polylineSegments)
                      MapLine(segment, color: _riding ? Colors.orange : AppTheme.accent),
                ],
                pins: [
                  if (route != null) ...[
                    for (final stop in route.stops) MapPin(stop.point, MapPinStyle.stop),
                    MapPin(route.stops.last.point, MapPinStyle.terminal),
                  ],
                  if (origin != null) MapPin(origin, MapPinStyle.origin),
                ],
              ),
              if (route == null && !_keypadVisible) _emptyState(l10n, origin == null),
              if (route != null && !_keypadVisible)
                Positioned(left: 10, right: 10, bottom: 34, child: _routeInfo(l10n, route)),
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
    return route != null ? 100 : 0;
  }

  Widget _emptyState(AppLocalizations l10n, bool noLocation) => Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.bus, size: 36, color: AppTheme.secondaryText),
              const SizedBox(height: 10),
              Text(l10n.routeMapEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.secondaryText)),
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
    final label = _directionLabel(route);
    final distance = _riding ? controller.distanceLeftMeters : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(route.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (label != null)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                  ),
                Text(
                  _riding ? l10n.ridingLabel : l10n.routeBoardHint,
                  style: TextStyle(fontSize: 12, color: _riding ? Colors.orange : AppTheme.tertiaryText),
                ),
              ],
            ),
          ),
          if (distance != null) ...[
            Text(
              '${l10n.distanceLeft} ${DistanceColorBand.format(distance)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
          ],
          const Icon(CupertinoIcons.bus, size: 16, color: AppTheme.accent),
          const SizedBox(width: 2),
          Text('${route.stops.length}', style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
        ],
      ),
    );
  }
}
