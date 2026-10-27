import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../models/route_catalog.dart';
import '../services/geo.dart';
import '../state/trip_controller.dart';
import 'bus_map.dart';
import 'places_screen.dart';
import 'theme.dart';

class _Place {
  const _Place(this.name, this.point, [this.subtitle]);
  final String name;
  final GeoPoint point;
  final String? subtitle;
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
  bool showsRoleToggle = true,
  TripController? controller,
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
        showsRoleToggle: showsRoleToggle,
        controller: controller,
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
    this.showsRoleToggle = true,
    this.controller,
  });

  /// 出発地／目的地の切り替えを出すか。登録地の編集では出さない。
  final bool showsRoleToggle;

  /// あれば「履歴から探す」「登録地から探す」を出す。
  final TripController? controller;

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
    final response = await http
        .get(
          _nominatim.replace(queryParameters: {'q': q, 'format': 'jsonv2', 'limit': '10', 'accept-language': language}),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    final places = <_Place>[];
    for (final item in list.whereType<Map>()) {
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat == null || lon == null) continue;
      final display = item['display_name'] as String?;
      final hasName = (item['name'] as String?)?.isNotEmpty == true;
      final name = hasName ? item['name'] as String : display ?? q;
      places.add(_Place(name, GeoPoint(lat, lon), hasName ? display : null));
    }
    return places;
  }

  /// Photon は GeoJSON。座標は [経度, 緯度]。対応言語外は既定（現地名）に任せる。
  /// 近くを優先する効きが弱いので、多めに取って地図の中心から近い順に並べる。
  Future<List<_Place>> _searchPhoton(String q, String language) async {
    final center = widget.searchCenter ?? widget.initialCenter;
    final response = await http
        .get(
          _photon.replace(
            queryParameters: {
              'q': q,
              'limit': '20',
              if (const {'en', 'de', 'fr'}.contains(language)) 'lang': language,
              if (center != null) 'lat': '${center.latitude}',
              if (center != null) 'lon': '${center.longitude}',
              if (center != null) 'zoom': '12',
              if (center != null) 'location_bias_scale': '0.1',
            },
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final features = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['features'] as List? ?? const [];
    final places = <_Place>[];
    for (final feature in features.whereType<Map>()) {
      final coords = (feature['geometry'] as Map?)?['coordinates'] as List?;
      if (coords == null || coords.length < 2) continue;
      final props = feature['properties'] as Map? ?? const {};
      final parts = [
        props['name'],
        props['street'],
        props['city'],
      ].whereType<String>().where((p) => p.isNotEmpty).toSet().toList();
      final country = props['country'] as String?;
      places.add(
        _Place(
          parts.isEmpty ? q : parts.first,
          GeoPoint((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
          [...parts.skip(1), ?country].join(', '),
        ),
      );
    }
    if (center != null) {
      places.sort((a, b) => Geo.distance(center, a.point).compareTo(Geo.distance(center, b.point)));
    }
    return places.take(10).toList();
  }

  void _choose(String name, GeoPoint point, [String? subtitle]) {
    Navigator.of(context).pop(PickedPlace(_role, Destination(name: name, point: point, subtitle: subtitle)));
  }

  Future<void> _fromList(Future<Destination?> Function(BuildContext, TripController) open) async {
    final controller = widget.controller;
    if (controller == null) return;
    final picked = await open(context, controller);
    if (picked != null && mounted) Navigator.of(context).pop(PickedPlace(_role, picked));
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    _role == PickRole.origin ? l10n.pickerTitleOrigin : l10n.pickerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Semantics(label: l10n.cancel, child: const Icon(CupertinoIcons.xmark, size: 24)),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showsRoleToggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<PickRole>(
                  groupValue: _role,
                  onValueChanged: (role) {
                    if (role != null) setState(() => _role = role);
                  },
                  children: {PickRole.origin: Text(l10n.roleOrigin), PickRole.destination: Text(l10n.roleDestination)},
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
          if (widget.controller != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _ListButton(
                      icon: CupertinoIcons.clock,
                      label: l10n.searchFromHistory,
                      onTap: () => _fromList(showHistory),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ListButton(
                      icon: CupertinoIcons.map_pin_ellipse,
                      label: l10n.searchFromSavedPlaces,
                      onTap: () => _fromList(showSavedPlaces),
                    ),
                  ),
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
                    subtitle: place.subtitle == null || place.subtitle!.isEmpty
                        ? null
                        : Text(place.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _choose(place.name, place.point, place.subtitle),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _role == PickRole.origin ? l10n.pickerLongPressHintOrigin : l10n.pickerLongPressHint,
              style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
            ),
          ),
          Expanded(
            child: BusMap(
              initialCenter: center,
              initialZoom: widget.initialCenter == null ? 12 : 15,
              onLongPress: (point) => _choose(
                '${l10n.destinationPickedPoint} '
                '(${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})',
                point,
              ),
              pins: [if (widget.initialCenter != null) MapPin(center, MapPinStyle.place)],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListButton extends StatelessWidget {
  const _ListButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, color: AppTheme.accent),
          ),
        ),
      ],
    ),
  );
}
