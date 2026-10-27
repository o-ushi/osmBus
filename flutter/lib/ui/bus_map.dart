import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../models/route_catalog.dart';
import '../services/google_maps_config.dart';
import 'theme.dart';

const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// OSM のタイルが取れないとき（回線の DNS が tile.openstreetmap.org を引けない場合など）の予備。
/// 中身は同じ OSM データ。
const String fallbackTileUrl = 'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png';

/// flutter_map は User-Agent を `flutter_map (<この値>)` にする。
const String osmUserAgentPackage = 'com.osamushikubo.osmBus';

LatLng toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

gm.LatLng _toGoogle(GeoPoint p) => gm.LatLng(p.latitude, p.longitude);

/// 標準タイルは黄・緑・赤が強い。彩度 0.5・コントラスト 0.9 に落とし、少し明るくする。
/// 路線とピンには掛けない。
const List<double> _mutedOsmMatrix = <double>[
  0.5457, 0.3218, 0.0325, 0, 22.8, // R
  0.0957, 0.7718, 0.0325, 0, 22.8, // G
  0.0957, 0.3218, 0.4825, 0, 22.8, // B
  0, 0, 0, 1, 0, // A
];

/// オフラインでは取得に失敗したタイルを空白のままにする（例外として扱わない）。
Widget osmTileLayer() => TileLayer(
      urlTemplate: osmTileUrl,
      fallbackUrl: fallbackTileUrl,
      userAgentPackageName: osmUserAgentPackage,
      tileProvider: NetworkTileProvider(silenceExceptions: true),
      tileBuilder: _mutedOsmTile,
    );

Widget _mutedOsmTile(BuildContext context, Widget tileWidget, TileImage tile) => ColorFiltered(
      colorFilter: const ColorFilter.matrix(_mutedOsmMatrix),
      child: tileWidget,
    );

/// 画面幅に収まる OSM クレジット。
/// [SimpleAttributionWidget] は「flutter_map | ©」と出典を横並びの [Text] にするため、
/// 文字が大きいと右にはみ出す。
Widget osmAttribution() => const _OsmAttribution();

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  static const _label = 'flutter_map | © OpenStreetMap contributors, OSM France';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Text(_label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

/// 地図に置く印の種類。OSM と Google で同じ絵を描く。
enum MapPinStyle {
  /// 路線の停留所（白丸に青の縁）。
  stop(12),

  /// 乗車停留所。
  board(36, icon: Icons.trip_origin, iconSize: 34, color: Color(0xFF388E3C)),

  /// 降車停留所。
  alight(36, icon: Icons.place, iconSize: 34, color: Color(0xFFD32F2F)),

  /// 乗換の停留所（Swift の乗換ピンと同じく白丸に橙の縁と分岐の印）。
  transfer(40, icon: Icons.alt_route, iconSize: 22, color: Colors.orange),

  /// 路線の終点。
  terminal(36, icon: Icons.flag_circle, iconSize: 34, color: Colors.red),

  /// 出発地（現在地または手動の出発地）。
  origin(22),

  /// 地図シートの中心にした地点。
  place(32, icon: CupertinoIcons.location_fill, iconSize: 24, color: AppTheme.accent);

  const MapPinStyle(this.size, {this.icon, this.iconSize = 0, this.color = AppTheme.accent});

  final double size;
  final IconData? icon;
  final double iconSize;
  final Color color;
}

class MapPin {
  const MapPin(this.point, this.style);

  final GeoPoint point;
  final MapPinStyle style;
}

class MapLine {
  const MapLine(this.points, {required this.color, this.width = 5, this.dashed = false});

  final List<GeoPoint> points;
  final Color color;
  final double width;

  /// 徒歩の区間（Swift と同じく点線）。
  final bool dashed;
}

/// 表示中の地図（OSM / Google のどちらか）のカメラを動かす。
class BusMapController {
  _BusMapState? _state;

  void fit(List<GeoPoint> points) => _state?._fit(points);
}

/// アプリの地図。Google マップを使える設定なら Google、そうでなければ OSM のタイルで描く。
/// 路線と停留所はどちらも端末内の OSM データ。
class BusMap extends StatefulWidget {
  const BusMap({
    super.key,
    this.controller,
    required this.initialCenter,
    this.initialZoom = 14,
    this.initialFit,
    this.fitPadding = const EdgeInsets.all(40),
    this.overlayInsets = EdgeInsets.zero,
    this.maxZoom = 17,
    this.lines = const [],
    this.pins = const [],
    this.onLongPress,
  });

  final BusMapController? controller;
  final GeoPoint initialCenter;
  final double initialZoom;

  /// あれば、最初にこの点がすべて入るようにする。
  final List<GeoPoint>? initialFit;
  final EdgeInsets fitPadding;

  /// 地図の上に重ねた部品が隠す範囲。Google のロゴとカメラの寄せ先をここから外す。
  final EdgeInsets overlayInsets;
  final double maxZoom;
  final List<MapLine> lines;

  /// 後ろのものほど上に描く。
  final List<MapPin> pins;
  final ValueChanged<GeoPoint>? onLongPress;

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _osm = MapController();
  gm.GoogleMapController? _google;

  /// 画素密度ごとの Google 用の印の画像。
  static final Map<(MapPinStyle, double), gm.BitmapDescriptor> _icons = {};

  GoogleMapsConfig get _config => GoogleMapsConfig.instance;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _config.addListener(_configChanged);
  }

  @override
  void didUpdateWidget(BusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIcons();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _config.removeListener(_configChanged);
    super.dispose();
  }

  void _configChanged() {
    // Google と OSM が入れ替わったら、前の地図のコントローラは使えない。
    if (!_config.useGoogle) _google = null;
    setState(() {});
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    if (!_config.useGoogle) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final missing = MapPinStyle.values.where((s) => !_icons.containsKey((s, dpr))).toList();
    if (missing.isEmpty) return;
    for (final style in missing) {
      _icons[(style, dpr)] = await _render(style, dpr);
    }
    if (mounted) setState(() {});
  }

  static Future<gm.BitmapDescriptor> _render(MapPinStyle style, double dpr) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    _PinPainter(style).paint(canvas, Size.square(style.size));
    final pixels = (style.size * dpr).ceil();
    final image = await recorder.endRecording().toImage(pixels, pixels);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return gm.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr);
  }

  void _fit(List<GeoPoint> points) {
    if (points.length < 2) return;
    if (_config.useGoogle) {
      _fitGoogle(points);
      return;
    }
    try {
      _osm.fitCamera(CameraFit.coordinates(
        coordinates: points.map(toLatLng).toList(),
        padding: widget.fitPadding,
        maxZoom: widget.maxZoom,
      ));
    } catch (_) {}
  }

  Future<void> _fitGoogle(List<GeoPoint> points) async {
    final controller = _google;
    if (controller == null || points.isEmpty) return;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    // 1 点に近いときは寄りすぎないよう、最大ズームで中心に置く。
    final update = (north - south) < 0.0005 && (east - west) < 0.0005
        ? gm.CameraUpdate.newLatLngZoom(gm.LatLng((south + north) / 2, (west + east) / 2), widget.maxZoom)
        : gm.CameraUpdate.newLatLngBounds(
            gm.LatLngBounds(southwest: gm.LatLng(south, west), northeast: gm.LatLng(north, east)),
            widget.fitPadding.top,
          );
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await controller.moveCamera(update);
        return;
      } catch (_) {
        // 地図の大きさが決まる前は動かせないので、少し待ってやり直す。
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _config.useGoogle ? _buildGoogle(context) : _buildOsm();

  Widget _buildGoogle(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final onLongPress = widget.onLongPress;
    return Stack(
      children: [
        gm.GoogleMap(
          initialCameraPosition: gm.CameraPosition(
            target: _toGoogle(widget.initialCenter),
            zoom: widget.initialZoom,
          ),
          padding: widget.overlayInsets,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) {
            _google = controller;
            final fit = widget.initialFit;
            if (fit != null) _fitGoogle(fit);
          },
          onLongPress: onLongPress == null ? null : (p) => onLongPress(GeoPoint(p.latitude, p.longitude)),
          polylines: {
            for (final (i, line) in widget.lines.indexed)
              gm.Polyline(
                polylineId: gm.PolylineId('line-$i'),
                points: line.points.map(_toGoogle).toList(),
                color: line.color,
                width: line.width.round(),
                patterns: line.dashed ? [gm.PatternItem.dash(12), gm.PatternItem.gap(8)] : const [],
              ),
          },
          markers: {
            for (final (i, pin) in widget.pins.indexed)
              if (_icons[(pin.style, dpr)] case final icon?)
                gm.Marker(
                  markerId: gm.MarkerId('pin-$i'),
                  position: _toGoogle(pin.point),
                  icon: icon,
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: i,
                  consumeTapEvents: true,
                ),
          },
        ),
        // 路線と停留所は OSM のデータなので、その出典を出す。
        Positioned(
          right: 4 + widget.overlayInsets.right,
          bottom: 4 + widget.overlayInsets.bottom,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              color: Colors.white.withValues(alpha: 0.7),
              child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.black87)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOsm() {
    final fit = widget.initialFit;
    final onLongPress = widget.onLongPress;
    return FlutterMap(
      mapController: _osm,
      options: MapOptions(
        initialCenter: toLatLng(widget.initialCenter),
        initialZoom: widget.initialZoom,
        initialCameraFit: fit == null || fit.isEmpty
            ? null
            : CameraFit.coordinates(
                coordinates: fit.map(toLatLng).toList(),
                padding: widget.fitPadding,
                maxZoom: widget.maxZoom,
              ),
        onLongPress: onLongPress == null ? null : (_, point) => onLongPress(GeoPoint(point.latitude, point.longitude)),
      ),
      children: [
        osmTileLayer(),
        if (widget.lines.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (final line in widget.lines)
                Polyline(
                  points: line.points.map(toLatLng).toList(),
                  strokeWidth: line.width,
                  color: line.color,
                  pattern: line.dashed ? StrokePattern.dashed(segments: const [12, 8]) : const StrokePattern.solid(),
                ),
            ],
          ),
        if (widget.pins.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final pin in widget.pins)
                Marker(
                  point: toLatLng(pin.point),
                  width: pin.style.size,
                  height: pin.style.size,
                  child: CustomPaint(painter: _PinPainter(pin.style)),
                ),
            ],
          ),
        osmAttribution(),
      ],
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.style);

  final MapPinStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    switch (style) {
      case MapPinStyle.stop:
        _ring(canvas, center, size.shortestSide / 2, fill: Colors.white, border: AppTheme.brandBlue, width: 2.5);
      case MapPinStyle.origin:
        _ring(canvas, center, size.shortestSide / 2, fill: AppTheme.accent, border: Colors.white, width: 3);
      case MapPinStyle.transfer:
        _ring(canvas, center, size.shortestSide / 2 - 1, fill: Colors.white, border: style.color, width: 2);
        _glyph(canvas, center, style);
      case MapPinStyle.board || MapPinStyle.alight || MapPinStyle.terminal || MapPinStyle.place:
        _glyph(canvas, center, style);
    }
  }

  static void _glyph(Canvas canvas, Offset center, MapPinStyle style) {
    final icon = style.icon!;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: style.iconSize,
          height: 1,
          color: style.color,
        ),
      ),
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  static void _ring(Canvas canvas, Offset center, double radius,
      {required Color fill, required Color border, required double width}) {
    canvas.drawCircle(center, radius - width / 2, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius - width / 2,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => oldDelegate.style != style;
}
