import 'dart:isolate';
import 'dart:math' as math;

import '../models/local_itinerary.dart';
import '../models/route_catalog.dart';
import 'geo.dart';

/// 保持している路線の停留所列だけで旅程を出す（§8）。Google は呼ばない。
abstract final class LocalPlanner {
  static const double boardRadiusMeters = 700;
  static const double alightRadiusMeters = 550;
  static const double transferRadiusMeters = 280;
  static const double minRideFromOriginMeters = 250;

  static const double gridDegrees = 0.003;
  static const int maxTransferSamples = 80;
  static const int secondHopSeeds = 5;
  static const int maxSecondHopComparisons = 2000;

  static List<LocalItinerary> plan(
    List<RouteRecord> records,
    GeoPoint origin,
    GeoPoint destination,
  ) {
    final routes = <_Route>[
      for (final r in records)
        if (r.hasGeometry && r.stops.length >= 2) _Route(r, origin, destination),
    ]..sort((a, b) => a.record.relationId.compareTo(b.record.relationId));
    if (routes.isEmpty) return const [];

    final grid = _StopGrid(routes);
    final results = <LocalItinerary>[];

    for (var ai = 0; ai < routes.length; ai++) {
      final a = routes[ai];
      final board = a.boardIndex;
      if (board == null) continue;

      final directAlight = a.bestAlightAfter[board];
      if (directAlight != null) {
        final leg = a.leg(board, directAlight);
        results.add(LocalItinerary(
          legs: [leg],
          walkMeters: a.originDistance[board] + a.destinationDistance[directAlight],
          bearing: _legBearing(leg),
        ));
        // 直通で着く路線からは乗換案を探さない（並行路線どうしの乗り継ぎが表に並ぶのを防ぐ）。
        continue;
      }

      final transfer = _bestTransfer(ai, routes, grid);
      if (transfer?.oneTransfer case final one?) results.add(one);
      if (transfer?.twoTransfers case final two?) results.add(two);
    }

    results.sort((x, y) {
      final id = x.firstLeg.relationId.compareTo(y.firstLeg.relationId);
      if (id != 0) return id;
      return x.legs.length.compareTo(y.legs.length);
    });
    return results;
  }

  /// 第 1 レグの乗車停留所から、ポリラインの 1/5 付近の点への方位（§8.5）。
  static double _legBearing(ItineraryLeg leg) {
    final path = leg.path;
    final n = path.length;
    if (n >= 2) {
      final index = math.min(n - 1, math.max(1, n ~/ 5));
      return Geo.bearing(leg.boardStop.point, path[index]);
    }
    return Geo.bearing(leg.boardStop.point, leg.alightStop.point);
  }

  static _TransferResult? _bestTransfer(int ai, List<_Route> routes, _StopGrid grid) {
    final a = routes[ai];
    final board = a.boardIndex!;
    final originWalk = a.originDistance[board];

    _Candidate? best;
    // 2 回乗換の種。B ごとに徒歩が最小の接続を 1 つ。
    final seeds = <int, _Hop>{};

    for (final t in _samplesAfter(a, board)) {
      if (a.originDistance[t] < minRideFromOriginMeters) continue;
      final tPoint = a.record.stops[t].point;
      for (final entry in grid.near(tPoint)) {
        if (entry.route == ai) continue;
        final gap = Geo.distance(tPoint, routes[entry.route].record.stops[entry.stop].point);
        if (gap > transferRadiusMeters) continue;
        final walkSoFar = originWalk + gap;

        final seed = seeds[entry.route];
        if (seed == null || walkSoFar < seed.walkSoFar) {
          seeds[entry.route] = _Hop(entry.route, t, entry.stop, walkSoFar);
        }

        final b = routes[entry.route];
        final alight = b.bestAlightAfter[entry.stop];
        if (alight == null) continue;
        final candidate = _Candidate(
          walk: walkSoFar + b.destinationDistance[alight],
          hops: [_LegRef(ai, board, t), _LegRef(entry.route, entry.stop, alight)],
        );
        best = _better(best, candidate, routes);
      }
    }

    final ordered = seeds.values.toList()..sort((x, y) => x.walkSoFar.compareTo(y.walkSoFar));
    _Candidate? bestSecond;
    var comparisons = 0;
    outer:
    for (final hop in ordered.take(secondHopSeeds)) {
      final b = routes[hop.route];
      for (final t2 in _samplesAfter(b, hop.boardStop)) {
        final t2Point = b.record.stops[t2].point;
        for (final entry in grid.near(t2Point)) {
          if (entry.route == ai || entry.route == hop.route) continue;
          if (++comparisons > maxSecondHopComparisons) break outer;
          final c = routes[entry.route];
          final alight = c.bestAlightAfter[entry.stop];
          if (alight == null) continue;
          final gap = Geo.distance(t2Point, c.record.stops[entry.stop].point);
          if (gap > transferRadiusMeters) continue;
          final candidate = _Candidate(
            walk: hop.walkSoFar + gap + c.destinationDistance[alight],
            hops: [
              _LegRef(ai, board, hop.alightOnA),
              _LegRef(hop.route, hop.boardStop, t2),
              _LegRef(entry.route, entry.stop, alight),
            ],
          );
          bestSecond = _better(bestSecond, candidate, routes);
        }
      }
    }

    if (best == null && bestSecond == null) return null;
    return _TransferResult(
      oneTransfer: best?.build(routes),
      twoTransfers: bestSecond?.build(routes),
    );
  }

  static _Candidate _better(_Candidate? current, _Candidate next, List<_Route> routes) {
    if (current == null) return next;
    if (next.walk < current.walk) return next;
    if (next.walk > current.walk) return current;
    return next.ride(routes) < current.ride(routes) ? next : current;
  }

  /// 乗車停留所より後ろの添字。停留所が 80 を超える路線は均等に 80 点まで間引く。
  static Iterable<int> _samplesAfter(_Route route, int start) sync* {
    final first = start + 1;
    final count = route.record.stops.length - first;
    if (count <= 0) return;
    if (route.record.stops.length <= maxTransferSamples || count <= maxTransferSamples) {
      for (var i = first; i < route.record.stops.length; i++) {
        yield i;
      }
      return;
    }
    var previous = -1;
    for (var k = 0; k < maxTransferSamples; k++) {
      final index = first + (k * (count - 1)) ~/ (maxTransferSamples - 1);
      if (index != previous) yield index;
      previous = index;
    }
  }
}

class _TransferResult {
  const _TransferResult({this.oneTransfer, this.twoTransfers});
  final LocalItinerary? oneTransfer;
  final LocalItinerary? twoTransfers;
}

class _Hop {
  const _Hop(this.route, this.alightOnA, this.boardStop, this.walkSoFar);
  final int route;
  final int alightOnA;
  final int boardStop;
  final double walkSoFar;
}

class _LegRef {
  const _LegRef(this.route, this.board, this.alight);
  final int route;
  final int board;
  final int alight;
}

class _Candidate {
  _Candidate({required this.walk, required this.hops});

  final double walk;
  final List<_LegRef> hops;
  double? _ride;

  double ride(List<_Route> routes) => _ride ??= hops.fold<double>(
        0,
        (sum, h) => sum + routes[h.route].rideMeters(h.board, h.alight),
      );

  LocalItinerary build(List<_Route> routes) {
    final legs = [for (final h in hops) routes[h.route].leg(h.board, h.alight)];
    return LocalItinerary(legs: legs, walkMeters: walk, bearing: LocalPlanner._legBearing(legs.first));
  }
}

class _GridEntry {
  const _GridEntry(this.route, this.stop);
  final int route;
  final int stop;
}

/// 0.003 度のグリッド。検索は自セルと隣接 8 セル。
class _StopGrid {
  _StopGrid(List<_Route> routes) {
    for (var r = 0; r < routes.length; r++) {
      final stops = routes[r].record.stops;
      for (var s = 0; s < stops.length; s++) {
        _cells.putIfAbsent(_key(_cell(stops[s].latitude), _cell(stops[s].longitude)), () => [])
            .add(_GridEntry(r, s));
      }
    }
  }

  final Map<int, List<_GridEntry>> _cells = {};

  static int _cell(double degrees) => (degrees / LocalPlanner.gridDegrees).floor();
  static int _key(int lat, int lon) => lat * 1000000 + lon;

  Iterable<_GridEntry> near(GeoPoint point) sync* {
    final lat = _cell(point.latitude);
    final lon = _cell(point.longitude);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final cell = _cells[_key(lat + dy, lon + dx)];
        if (cell != null) yield* cell;
      }
    }
  }
}

/// 計画中だけ使う路線の索引。
class _Route {
  _Route(this.record, GeoPoint origin, GeoPoint destination)
      : originDistance = [for (final s in record.stops) Geo.distance(origin, s.point)],
        destinationDistance = [for (final s in record.stops) Geo.distance(s.point, destination)] {
    boardIndex = _nearest(originDistance, LocalPlanner.boardRadiusMeters);
    bestAlightAfter = List<int?>.filled(record.stops.length, null);
    int? best;
    for (var j = record.stops.length - 1; j >= 0; j--) {
      bestAlightAfter[j] = best;
      final d = destinationDistance[j];
      if (d <= LocalPlanner.alightRadiusMeters &&
          (best == null || d <= destinationDistance[best])) {
        best = j;
      }
    }
  }

  final RouteRecord record;
  final List<double> originDistance;
  final List<double> destinationDistance;
  late final int? boardIndex;

  /// 添字 u より後ろで目的地に最も近い降車停留所（同距離なら添字が小さい方）。
  late final List<int?> bestAlightAfter;

  late final List<GeoPoint> _flat = [for (final seg in record.polylineSegments) ...seg];
  late final List<double> _cumulative = () {
    final out = List<double>.filled(_flat.length, 0);
    for (var i = 1; i < _flat.length; i++) {
      out[i] = out[i - 1] + Geo.distance(_flat[i - 1], _flat[i]);
    }
    return out;
  }();
  final Map<int, int> _vertexForStop = {};

  static int? _nearest(List<double> distances, double radius) {
    int? best;
    for (var i = 0; i < distances.length; i++) {
      if (distances[i] <= radius && (best == null || distances[i] < distances[best])) best = i;
    }
    return best;
  }

  int _vertex(int stop) => _vertexForStop.putIfAbsent(stop, () {
        final p = record.stops[stop].point;
        var best = 0;
        var bestDistance = double.infinity;
        for (var i = 0; i < _flat.length; i++) {
          final d = Geo.distance(p, _flat[i]);
          if (d < bestDistance) {
            bestDistance = d;
            best = i;
          }
        }
        return best;
      });

  double rideMeters(int board, int alight) {
    if (_flat.length >= 2) {
      final start = _vertex(board);
      final end = _vertex(alight);
      if (end > start) return _cumulative[end] - _cumulative[start];
    }
    return Geo.distance(record.stops[board].point, record.stops[alight].point);
  }

  List<GeoPoint> path(int board, int alight) {
    if (_flat.length >= 2) {
      final start = _vertex(board);
      final end = _vertex(alight);
      if (end > start) return _flat.sublist(start, end + 1);
    }
    return [record.stops[board].point, record.stops[alight].point];
  }

  ItineraryLeg leg(int board, int alight) => ItineraryLeg(
        relationId: record.relationId,
        ref: record.ref,
        routeName: record.name,
        boardIndex: board,
        alightIndex: alight,
        boardStop: record.stops[board],
        alightStop: record.stops[alight],
        path: path(board, alight),
        rideMeters: rideMeters(board, alight),
      );
}

/// 出発地と目的地が同じあいだ結果を持つ。計算は別 isolate で行う。
class PlannerCache {
  static const double recomputeDistanceMeters = 150;

  GeoPoint? _origin;
  GeoPoint? _destination;
  int? _catalogVersion;
  List<LocalItinerary>? _result;

  void invalidate() => _result = null;

  /// キャッシュが使えれば同期的に返す。
  List<LocalItinerary>? cached({
    required GeoPoint origin,
    required GeoPoint destination,
    required int catalogVersion,
  }) {
    final previous = _origin;
    if (_result == null || previous == null) return null;
    if (_destination != destination || _catalogVersion != catalogVersion) return null;
    if (Geo.distance(previous, origin) >= recomputeDistanceMeters) return null;
    return _result;
  }

  Future<List<LocalItinerary>> compute({
    required List<RouteRecord> routes,
    required GeoPoint origin,
    required GeoPoint destination,
    required int catalogVersion,
  }) async {
    final hit = cached(origin: origin, destination: destination, catalogVersion: catalogVersion);
    if (hit != null) return hit;
    final result = await Isolate.run(() => LocalPlanner.plan(routes, origin, destination));
    _origin = origin;
    _destination = destination;
    _catalogVersion = catalogVersion;
    _result = result;
    return result;
  }
}
