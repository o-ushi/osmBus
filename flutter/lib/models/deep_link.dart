import 'destination.dart';
import 'route_catalog.dart';

/// `osmbus://destination?name=…&lat=…&lng=…&subtitle=…` で目的地を受け取る（Swift の `OsmBusDeepLink`）。
abstract final class OsmBusDeepLink {
  static const String scheme = 'osmbus';

  static Destination? parseDestination(Uri uri) {
    if (uri.scheme.toLowerCase() != scheme) return null;
    final query = uri.queryParameters;
    final name = query['name']?.trim();
    final lat = double.tryParse(query['lat'] ?? '');
    final lng = double.tryParse(query['lng'] ?? '');
    if (name == null || name.isEmpty || lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    final subtitle = query['subtitle']?.trim();
    return Destination(
      name: name,
      subtitle: subtitle == null || subtitle.isEmpty ? null : subtitle,
      point: GeoPoint(lat, lng),
    );
  }
}
