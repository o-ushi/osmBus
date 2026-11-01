import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/route_catalog.dart';
import '../services/route_review.dart';
import '../state/trip_controller.dart';
import 'bus_map.dart';
import 'theme.dart';

/// 路線図・経路地図で、今見ている路線を確かめる入口の 1 行。警告の色にはしない。
/// 記憶が無ければ「この路線を確認」、あれば「直した順を使っています」。タップでレビューのシートを開く。
class StopOrderEditRow extends StatelessWidget {
  const StopOrderEditRow({super.key, required this.controller, required this.relationId});

  final TripController controller;
  final int relationId;

  @override
  Widget build(BuildContext context) {
    final route = controller.visibleCatalog.routes.where((r) => r.relationId == relationId).firstOrNull;
    if (route == null || route.stops.length < 2) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final custom = controller.hasCustomStops(relationId);
    final color = custom ? AppTheme.verdictGreen : AppTheme.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showRouteReview(context, controller, relationId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(custom ? CupertinoIcons.checkmark_seal : CupertinoIcons.search, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                custom ? l10n.stopOrderUsingCustom : l10n.routeReviewOpen,
                style: TextStyle(fontSize: 13, color: color),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppTheme.tertiaryText),
          ],
        ),
      ),
    );
  }
}

Future<T?> _sheet<T>(BuildContext context, Widget child, {double heightFactor = 0.85, bool enableDrag = true}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: enableDrag,
      backgroundColor: AppTheme.groupedBackground,
      builder: (_) => FractionallySizedBox(heightFactor: heightFactor, child: child),
    );

String _routeSubtitle(RouteRecord route) => [route.ref, ?route.directionText].join('  ');

const TextStyle _titleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
const TextStyle _sectionStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryText);
const TextStyle _noteStyle = TextStyle(fontSize: 13, color: AppTheme.secondaryText);

// MARK: - レビュー

/// 「この路線の確認」。開いたとき（押したとき）だけ所見を作り、採用するたびに作り直す。
Future<void> showRouteReview(BuildContext context, TripController controller, int relationId) {
  if (controller.shownRoute(relationId) == null) return Future.value();
  return _sheet<void>(context, _RouteReviewSheet(controller: controller, relationId: relationId));
}

class _RouteReviewSheet extends StatefulWidget {
  const _RouteReviewSheet({required this.controller, required this.relationId});

  final TripController controller;
  final int relationId;

  @override
  State<_RouteReviewSheet> createState() => _RouteReviewSheetState();
}

class _RouteReviewSheetState extends State<_RouteReviewSheet> {
  late RouteReview? _review = widget.controller.reviewRoute(widget.relationId);

  TripController get _controller => widget.controller;

  void _recompute() => setState(() => _review = _controller.reviewRoute(widget.relationId));

  Future<void> _editSelf() async {
    await showStopOrderEditor(context, _controller, widget.relationId);
    if (mounted) _recompute();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final review = _review;
    if (review == null) return const SizedBox.shrink();
    final custom = _controller.hasCustomStops(widget.relationId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Text(l10n.routeReviewTitle, style: _titleStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(_routeSubtitle(review.route), style: _noteStyle),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              _section(l10n.routeReviewOrder, _orderBody(l10n, review.order)),
              _section(l10n.routeReviewEnds, _endsBody(l10n, review.ends)),
              _section(l10n.routeReviewPlace, _placeBody(l10n, review.places)),
              _section(l10n.routeReviewMembership, _membershipBody(l10n, review.membership, review.partner != null)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(onPressed: _editSelf, child: Text(l10n.routeReviewEditSelf)),
                if (custom)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _controller.forgetCustomStops(widget.relationId);
                    },
                    child: Text(l10n.routeReviewReset),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: _sectionStyle),
            const SizedBox(height: 6),
            ...body,
          ],
        ),
      );

  Widget _text(String text, {TextStyle? style}) =>
      Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(text, style: style));

  List<Widget> _orderBody(AppLocalizations l10n, OrderFinding? order) {
    if (order == null) return [_text(l10n.routeReviewNothing, style: _noteStyle)];
    return [
      _text(l10n.routeReviewBacktrackIntro),
      for (final b in order.backtracks)
        _text(l10n.routeReviewBetween(
          b.stop.name,
          b.after?.name ?? l10n.routeReviewLineStart,
          b.before?.name ?? l10n.routeReviewLineEnd,
        )),
      if (order.partnerDisagrees) _text(l10n.routeReviewPartnerDiffers),
      _text(l10n.routeReviewProposal, style: _noteStyle),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          onPressed: () {
            _controller.applyOrderFinding(widget.relationId, order);
            _recompute();
          },
          child: Text(l10n.routeReviewUseThis),
        ),
      ),
    ];
  }

  List<Widget> _endsBody(AppLocalizations l10n, EndsFinding? ends) {
    if (ends == null) return [_text(l10n.routeReviewNothing, style: _noteStyle)];
    final proposal = ends.proposal;
    return [
      _text(l10n.routeReviewEndStart(ends.first.name, ends.firstMeters)),
      _text(l10n.routeReviewEndLast(ends.last.name, ends.lastMeters)),
      if (proposal != null) ...[
        _text(l10n.routeReviewEndsProposal, style: _noteStyle),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: () {
              _controller.saveCustomStops(widget.relationId, proposal);
              _recompute();
            },
            child: Text(l10n.routeReviewUseThis),
          ),
        ),
      ],
    ];
  }

  List<Widget> _placeBody(AppLocalizations l10n, List<PlaceFinding> places) {
    if (places.isEmpty) return [_text(l10n.routeReviewNothing, style: _noteStyle)];
    return [
      for (final place in places)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _text(l10n.routeReviewOffLine(place.stop.name, place.lineMeters)),
              if (place.replacement case final candidate?) ...[
                _text(
                  l10n.routeReviewReplaceCandidate(candidate.routeRef, candidate.lineMeters.round()),
                  style: _noteStyle,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () {
                      _controller.applyPlaceFinding(widget.relationId, place);
                      _recompute();
                    },
                    child: Text(l10n.routeReviewReplace),
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _membershipBody(AppLocalizations l10n, MembershipFinding m, bool hasPartner) {
    if (m.isEmpty) return [_text(l10n.routeReviewNothing, style: _noteStyle)];
    Widget candidate(StopCandidate c) =>
        _text('・${l10n.routeReviewCandidate(c.stop.name, c.routeRef, c.lineMeters.round())}');
    return [
      if (m.fromPartner.isNotEmpty) ...[
        _text(l10n.routeReviewFromPartner, style: _noteStyle),
        for (final c in m.fromPartner) candidate(c),
        const SizedBox(height: 6),
      ],
      if (m.fromOthers.isNotEmpty) ...[
        _text(l10n.routeReviewFromOthers, style: _noteStyle),
        for (final c in m.fromOthers) candidate(c),
        const SizedBox(height: 6),
      ],
      if (hasPartner && m.onlyHere.isNotEmpty) ...[
        _text(l10n.routeReviewOnlyHere, style: _noteStyle),
        for (final s in m.onlyHere) _text('・${s.name}'),
        const SizedBox(height: 6),
      ],
      _text(l10n.routeReviewNoAuto, style: _noteStyle),
    ];
  }
}

// MARK: - 自分で直す

/// 今の表示順の停留所を全部出し、並べ替え・削除・追加・場所の変更をするシート。
Future<void> showStopOrderEditor(BuildContext context, TripController controller, int relationId) {
  final route = controller.shownRoute(relationId);
  if (route == null) return Future.value();
  return _sheet<void>(context, _StopOrderEditor(controller: controller, route: route), enableDrag: false);
}

/// 並べ替えのキー。同じ停留所 ID が 2 度出る路線もあるので、行ごとに別のキーを持つ。
class _Entry {
  _Entry(this.key, this.stop);

  final int key;
  RouteStop stop;
}

class _StopOrderEditor extends StatefulWidget {
  const _StopOrderEditor({required this.controller, required this.route});

  final TripController controller;
  final RouteRecord route;

  @override
  State<_StopOrderEditor> createState() => _StopOrderEditorState();
}

class _StopOrderEditorState extends State<_StopOrderEditor> {
  late final List<_Entry> _entries = [for (final (i, s) in widget.route.stops.indexed) _Entry(i, s)];
  late int _nextKey = _entries.length;

  List<RouteStop> get _stops => [for (final e in _entries) e.stop];

  bool get _changed => !sameStops(_stops, widget.route.stops);

  TripController get _controller => widget.controller;

  /// [to] は [from] を取り除いたあとの位置。
  void _reorder(int from, int to) => setState(() => _entries.insert(to, _entries.removeAt(from)));

  void _delete(int index) {
    if (_entries.length <= 2) return;
    setState(() => _entries.removeAt(index));
  }

  Future<void> _editPlace(int index) async {
    final stop = _entries[index].stop;
    final local = stop.id < 0;
    final picked = await pickStopPlace(
      context,
      route: widget.route.copyWith(stops: _stops),
      initial: stop.point,
      initialName: stop.name,
      nameEditable: local,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _entries[index].stop = RouteStop(
        id: stop.id,
        name: local ? picked.name! : stop.name,
        latitude: picked.point.latitude,
        longitude: picked.point.longitude,
      );
    });
  }

  Future<void> _add() async {
    final review = _controller.reviewRoute(widget.route.relationId, stops: _stops);
    final ids = {for (final s in _stops) s.id};
    final candidates = [
      for (final c in [...?review?.membership.fromPartner, ...?review?.membership.fromOthers])
        if (!ids.contains(c.stop.id)) c,
    ];
    final choice = await _sheet<Object>(
      context,
      _AddStopSheet(
        fromPartner: [for (final c in candidates) if (review!.membership.fromPartner.contains(c)) c],
        fromOthers: [for (final c in candidates) if (review!.membership.fromOthers.contains(c)) c],
      ),
      heightFactor: 0.7,
    );
    if (!mounted || choice == null) return;
    if (choice is RouteStop) {
      setState(() => _entries.add(_Entry(_nextKey++, choice)));
      return;
    }
    final picked = await pickStopPlace(
      context,
      route: widget.route.copyWith(stops: _stops),
      nameEditable: true,
    );
    if (picked == null || !mounted) return;
    final stop = RouteStop(
      id: _controller.newLocalStopId(),
      name: picked.name!,
      latitude: picked.point.latitude,
      longitude: picked.point.longitude,
    );
    setState(() => _entries.add(_Entry(_nextKey++, stop)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = widget.route;
    final custom = _controller.hasCustomStops(route.relationId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Text(l10n.routeReviewEditSelf, style: _titleStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('${_routeSubtitle(route)}\n${l10n.stopOrderDragHint}', style: _noteStyle),
        ),
        Expanded(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: Text(l10n.stopEditAdd),
              ),
            ),
            children: [for (final (i, e) in _entries.indexed) _tile(l10n, i, e)],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _changed
                      ? () {
                          Navigator.pop(context);
                          _controller.saveCustomStops(route.relationId, _stops);
                        }
                      : null,
                  child: Text(l10n.stopOrderUseThis),
                ),
                if (custom)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _controller.forgetCustomStops(route.relationId);
                    },
                    child: Text(l10n.routeReviewReset),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(AppLocalizations l10n, int index, _Entry entry) {
    final stop = entry.stop;
    return Padding(
      key: ValueKey(entry.key),
      padding: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        dense: true,
        tileColor: Colors.white,
        leading: Text('${index + 1}', style: const TextStyle(color: AppTheme.secondaryText)),
        title: Text(stop.name),
        subtitle: stop.id < 0 ? Text(l10n.stopEditAddedByYou) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.stopEditPlace,
              icon: const Icon(CupertinoIcons.map_pin_ellipse, size: 20),
              onPressed: () => _editPlace(index),
            ),
            IconButton(
              tooltip: l10n.stopEditDelete,
              icon: const Icon(CupertinoIcons.minus_circle, size: 20),
              onPressed: _entries.length > 2 ? () => _delete(index) : null,
            ),
            ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
          ],
        ),
      ),
    );
  }
}

/// 名前・ID・座標が順に全部同じか。
bool sameStops(List<RouteStop> a, List<RouteStop> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].name != b[i].name ||
        a[i].latitude != b[i].latitude ||
        a[i].longitude != b[i].longitude) {
      return false;
    }
  }
  return true;
}

/// 「停留所を足す」。復路と他路線の候補を出し、選んだ停留所を返す。「地図で場所を指定」は [pickOnMap]。
class _AddStopSheet extends StatelessWidget {
  const _AddStopSheet({required this.fromPartner, required this.fromOthers});

  final List<StopCandidate> fromPartner;
  final List<StopCandidate> fromOthers;

  static const Object pickOnMap = Object();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget tile(StopCandidate c) => ListTile(
          dense: true,
          tileColor: Colors.white,
          title: Text(c.stop.name),
          subtitle: Text(l10n.routeReviewCandidate(c.stop.name, c.routeRef, c.lineMeters.round())),
          onTap: () => Navigator.pop(context, c.stop),
        );
    Widget heading(String text) =>
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 6), child: Text(text, style: _noteStyle));
    return ListView(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(l10n.stopEditAdd, style: _titleStyle)),
        ListTile(
          tileColor: Colors.white,
          leading: const Icon(CupertinoIcons.map_pin, color: AppTheme.accent),
          title: Text(l10n.stopEditPickOnMap, style: const TextStyle(color: AppTheme.accent)),
          onTap: () => Navigator.pop(context, pickOnMap),
        ),
        if (fromPartner.isEmpty && fromOthers.isEmpty) heading(l10n.stopEditNoCandidates),
        if (fromPartner.isNotEmpty) ...[
          heading(l10n.routeReviewFromPartner),
          for (final c in fromPartner) Padding(padding: const EdgeInsets.only(bottom: 1), child: tile(c)),
        ],
        if (fromOthers.isNotEmpty) ...[
          heading(l10n.routeReviewFromOthers),
          for (final c in fromOthers) Padding(padding: const EdgeInsets.only(bottom: 1), child: tile(c)),
        ],
      ],
    );
  }
}

// MARK: - 地図で場所を指定

class PickedStopPlace {
  const PickedStopPlace(this.point, this.name);

  final GeoPoint point;

  /// [pickStopPlace] の nameEditable が true のときだけ。空ではない。
  final String? name;
}

/// 路線の線を出した地図に、長押しでピンを置く。緯度・経度の数値入力は地図の下に畳んである。
/// シートの中なので Google の地図は使わない。
Future<PickedStopPlace?> pickStopPlace(
  BuildContext context, {
  required RouteRecord route,
  GeoPoint? initial,
  String initialName = '',
  bool nameEditable = false,
}) =>
    _sheet<PickedStopPlace>(
      context,
      StopPlacePicker(route: route, initial: initial, initialName: initialName, nameEditable: nameEditable),
      heightFactor: 0.92,
      enableDrag: false,
    );

class StopPlacePicker extends StatefulWidget {
  const StopPlacePicker({
    super.key,
    required this.route,
    this.initial,
    this.initialName = '',
    this.nameEditable = false,
  });

  final RouteRecord route;
  final GeoPoint? initial;
  final String initialName;
  final bool nameEditable;

  @override
  State<StopPlacePicker> createState() => StopPlacePickerState();
}

@visibleForTesting
class StopPlacePickerState extends State<StopPlacePicker> {
  late GeoPoint? _pin = widget.initial;
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _lat = TextEditingController(text: _format(widget.initial?.latitude));
  late final TextEditingController _lon = TextEditingController(text: _format(widget.initial?.longitude));

  GeoPoint? get pin => _pin;

  static String _format(double? v) => v == null ? '' : v.toStringAsFixed(6);

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  /// 長押し。ピンを置き、数値欄もその位置に合わせる。
  void placePin(GeoPoint point) {
    setState(() {
      _pin = point;
      _lat.text = _format(point.latitude);
      _lon.text = _format(point.longitude);
    });
  }

  /// 数値欄。両方とも数値として読めたときだけピンを動かす。
  void _typed(String _) {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null) return;
    if (lat.abs() > 90 || lon.abs() > 180) return;
    setState(() => _pin = GeoPoint(lat, lon));
  }

  bool get _canConfirm => _pin != null && (!widget.nameEditable || _name.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = widget.route;
    final linePoints = [for (final s in route.polylineSegments) ...s];
    final center = _pin ?? route.stops.firstOrNull?.point ?? linePoints.firstOrNull ?? const GeoPoint(21.0285, 105.8542);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
            child: Text(l10n.stopEditPickOnMap, style: _titleStyle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.stopEditLongPressHint, style: _noteStyle),
          ),
          if (widget.nameEditable)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.stopEditName, filled: true, fillColor: Colors.white),
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: BusMap(
              initialCenter: center,
              initialZoom: 15,
              initialFit: widget.initial == null && linePoints.isNotEmpty ? linePoints : null,
              allowGoogle: false,
              showsMyLocation: false,
              lines: [for (final s in route.polylineSegments) MapLine(s, color: AppTheme.accent, width: 4)],
              pins: [
                for (final s in route.stops) MapPin(s.point, MapPinStyle.stop),
                if (_pin case final pin?) MapPin(pin, MapPinStyle.place),
              ],
              onLongPress: placePin,
            ),
          ),
          ExpansionTile(
            title: Text(l10n.stopEditCoordinates, style: const TextStyle(fontSize: 14)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              Row(
                children: [
                  Expanded(child: _numberField(_lat, l10n.stopEditLatitude)),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_lon, l10n.stopEditLongitude)),
                ],
              ),
            ],
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: FilledButton(
                onPressed: _canConfirm
                    ? () => Navigator.pop(
                          context,
                          PickedStopPlace(_pin!, widget.nameEditable ? _name.text.trim() : null),
                        )
                    : null,
                child: Text(l10n.stopEditConfirmPlace),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, isDense: true),
        onChanged: _typed,
      );
}
