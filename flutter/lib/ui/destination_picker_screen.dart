import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/route_catalog.dart';
import '../services/geo.dart';
import '../state/trip_controller.dart';
import 'route_map_screen.dart';
import 'theme.dart';

class _Place {
  const _Place(this.name, this.point);
  final String name;
  final GeoPoint point;
}

/// 地図で選ぶ地点の役割（Swift の `MapPickRole`）。
enum PickRole { origin, destination }

/// 選んだ地点と、その役割。
class PickedPlace {
  const PickedPlace(this.role, this.place);
  final PickRole role;
  final Destination place;
}

/// Swift 版と同じくシートで出す。地図操作とぶつかるので下スワイプでは閉じない。
/// [searchCenter] は地名検索で近くを優先する基準（現在地）。
Future<PickedPlace?> showDestinationPicker(
  BuildContext context, {
  PickRole initialRole = PickRole.destination,
  GeoPoint? initialCenter,
  GeoPoint? searchCenter,
}) {
  return showModalBottomSheet<PickedPlace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: AppTheme.groupedBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: DestinationPickerScreen(
        initialRole: initialRole,
        initialCenter: initialCenter,
        searchCenter: searchCenter,
      ),
    ),
  );
}

/// 地図の長押しで座標を確定。オンラインなら Nominatim で地名検索もできる。
class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({
    super.key,
    this.initialRole = PickRole.destination,
    this.initialCenter,
    this.searchCenter,
  });

  final PickRole initialRole;
  final GeoPoint? initialCenter;
  final GeoPoint? searchCenter;

  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  static final Uri _nominatim = Uri.parse('https://nominatim.openstreetmap.org/search');

  /// Nominatim に届かない回線向けの予備（OSM データの検索）。
  static final Uri _photon = Uri.parse('https://photon.komoot.io/api/');
  static const _headers = {'User-Agent': 'osmBus Flutter/1.0'};
  static const _fallbackCenter = GeoPoint(21.0285, 105.8542);

  final _query = TextEditingController();
  final _map = MapController();
  late PickRole _role = widget.initialRole;
  List<_Place> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      List<_Place> places;
      try {
        places = await _searchNominatim(q, language);
      } catch (_) {
        places = await _searchPhoton(q, language);
      }
      setState(() => _results = places);
    } catch (_) {
      setState(() => _error = l10n.searchFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<List<_Place>> _searchNominatim(String q, String language) async {
    final response = await http.get(
      _nominatim.replace(queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'limit': '10',
        'accept-language': language,
      }),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    final places = <_Place>[];
    for (final item in list.whereType<Map>()) {
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat == null || lon == null) continue;
      final name = (item['name'] as String?)?.isNotEmpty == true
          ? item['name'] as String
          : item['display_name'] as String? ?? q;
      places.add(_Place(name, GeoPoint(lat, lon)));
    }
    return places;
  }

  /// Photon は GeoJSON。座標は [経度, 緯度]。対応言語外は既定（現地名）に任せる。
  /// 近くを優先する効きが弱いので、多めに取って地図の中心から近い順に並べる。
  Future<List<_Place>> _searchPhoton(String q, String language) async {
    final center = widget.searchCenter ?? widget.initialCenter;
    final response = await http.get(
      _photon.replace(queryParameters: {
        'q': q,
        'limit': '20',
        if (const {'en', 'de', 'fr'}.contains(language)) 'lang': language,
        if (center != null) 'lat': '${center.latitude}',
        if (center != null) 'lon': '${center.longitude}',
        if (center != null) 'zoom': '12',
        if (center != null) 'location_bias_scale': '0.1',
      }),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final features = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['features'] as List? ?? const [];
    final places = <_Place>[];
    for (final feature in features.whereType<Map>()) {
      final coords = (feature['geometry'] as Map?)?['coordinates'] as List?;
      if (coords == null || coords.length < 2) continue;
      final props = feature['properties'] as Map? ?? const {};
      final parts = [props['name'], props['street'], props['city']]
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      places.add(_Place(
        parts.isEmpty ? q : parts.join(', '),
        GeoPoint((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
      ));
    }
    if (center != null) {
      places.sort((a, b) => Geo.distance(center, a.point).compareTo(Geo.distance(center, b.point)));
    }
    return places.take(10).toList();
  }

  void _choose(String name, GeoPoint point) {
    Navigator.of(context).pop(PickedPlace(_role, Destination(name: name, point: point)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final center = widget.initialCenter ?? _fallbackCenter;
    return Material(
      color: AppTheme.groupedBackground,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  _role == PickRole.origin ? l10n.pickerTitleOrigin : l10n.pickerTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Positioned(
                  right: 8,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<PickRole>(
                groupValue: _role,
                onValueChanged: (role) {
                  if (role != null) setState(() => _role = role);
                },
                children: {
                  PickRole.origin: Text(l10n.roleOrigin),
                  PickRole.destination: Text(l10n.roleDestination),
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    controller: _query,
                    placeholder: l10n.searchHint,
                    onSubmitted: (_) => _search(),
                    backgroundColor: const Color(0x1F767680),
                  ),
                ),
                if (_searching) const Padding(padding: EdgeInsets.only(left: 10), child: CupertinoActivityIndicator()),
              ],
            ),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final place = _results[index];
                  return ListTile(
                    dense: true,
                    tileColor: Colors.white,
                    leading: const Icon(CupertinoIcons.location_solid, color: AppTheme.accent),
                    title: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _choose(place.name, place.point),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(_role == PickRole.origin ? l10n.pickerLongPressHintOrigin : l10n.pickerLongPressHint, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: toLatLng(center),
                initialZoom: widget.initialCenter == null ? 12 : 15,
                onLongPress: (_, LatLng point) => _choose(
                  '${l10n.destinationPickedPoint} '
                  '(${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})',
                  GeoPoint(point.latitude, point.longitude),
                ),
              ),
              children: [
                osmTileLayer(),
                if (widget.initialCenter != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: toLatLng(center),
                        width: 32,
                        height: 32,
                        child: const Icon(CupertinoIcons.location_fill, color: AppTheme.accent),
                      ),
                    ],
                  ),
                osmAttribution(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
