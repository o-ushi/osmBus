import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/route_catalog.dart';
import '../state/trip_controller.dart';
import 'route_map_screen.dart';
import 'theme.dart';

class _Place {
  const _Place(this.name, this.point);
  final String name;
  final GeoPoint point;
}

/// Swift 版と同じくシートで出す。地図操作とぶつかるので下スワイプでは閉じない。
Future<Destination?> showDestinationPicker(BuildContext context, {GeoPoint? initialCenter}) {
  return showModalBottomSheet<Destination>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: AppTheme.groupedBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: DestinationPickerScreen(initialCenter: initialCenter),
    ),
  );
}

/// 地図の長押しで座標を確定。オンラインなら Nominatim で地名検索もできる。
class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key, this.initialCenter});

  final GeoPoint? initialCenter;

  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  static final Uri _nominatim = Uri.parse('https://nominatim.openstreetmap.org/search');
  static const _fallbackCenter = GeoPoint(21.0285, 105.8542);

  final _query = TextEditingController();
  final _map = MapController();
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
      final response = await http.get(
        _nominatim.replace(queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'limit': '10',
          'accept-language': language,
        }),
        headers: {'User-Agent': 'osmBus Flutter/1.0'},
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
      setState(() => _results = places);
    } catch (_) {
      setState(() => _error = l10n.searchFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(String name, GeoPoint point) {
    Navigator.of(context).pop(Destination(name: name, point: point));
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
                Text(l10n.pickerTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
            child: Text(l10n.pickerLongPressHint, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText)),
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
