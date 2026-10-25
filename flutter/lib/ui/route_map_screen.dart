import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/local_itinerary.dart';
import '../models/route_catalog.dart';

const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// OSM のタイルが取れないとき（回線の DNS が tile.openstreetmap.org を引けない場合など）の予備。
/// 中身は同じ OSM データ。
const String fallbackTileUrl = 'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png';

/// flutter_map は User-Agent を `flutter_map (<この値>)` にする。
const String osmUserAgentPackage = 'com.osamushikubo.osmBus';

LatLng toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

/// オフラインでは取得に失敗したタイルを空白のままにする（例外として扱わない）。
Widget osmTileLayer() => TileLayer(
      urlTemplate: osmTileUrl,
      fallbackUrl: fallbackTileUrl,
      userAgentPackageName: osmUserAgentPackage,
      tileProvider: NetworkTileProvider(silenceExceptions: true),
    );

Widget osmAttribution() => const SimpleAttributionWidget(
      source: Text('OpenStreetMap contributors, OSM France'),
    );

/// 番号表のタップ先。第 1 レグのポリライン、乗車停留所、降車停留所。
class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({super.key, required this.itinerary});

  final LocalItinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final leg = itinerary.firstLeg;
    final points = leg.path.map(toLatLng).toList();
    final board = toLatLng(leg.boardStop.point);
    final alight = toLatLng(leg.alightStop.point);
    final scheme = Theme.of(context).colorScheme;

    Marker stopMarker(LatLng point, Color color, IconData icon) => Marker(
          point: point,
          width: 36,
          height: 36,
          child: Icon(icon, color: color, size: 34),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeMapTitle(leg.ref))),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [board, alight, ...points],
                  padding: const EdgeInsets.fromLTRB(48, 56, 48, 110),
                  maxZoom: 17,
                ),
              ),
              children: [
                osmTileLayer(),
                PolylineLayer(
                  polylines: [Polyline(points: points, strokeWidth: 5, color: scheme.primary)],
                ),
                MarkerLayer(
                  markers: [
                    stopMarker(board, Colors.green.shade700, Icons.trip_origin),
                    stopMarker(alight, Colors.red.shade700, Icons.place),
                  ],
                ),
                osmAttribution(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: ListTile(
              title: Text(l10n.boardAt(leg.boardStop.name)),
              subtitle: Text(
                '${l10n.alightAt(leg.alightStop.name)}\n'
                '${l10n.walkMeters(itinerary.walkMeters.round())}',
              ),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }
}
