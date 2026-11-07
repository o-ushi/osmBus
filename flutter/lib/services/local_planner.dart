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

  /// 乗換 1 回あたりの時間の重み（秒）。乗換案は「徒歩・乗車・乗換」の概算時間が最小のものを選ぶ。
  static const double transferPenaltySeconds = 300;

  /// 寄り道の上限。徒歩と乗車の合計が「直線距離 × 2 + 2km」を超える案は出さない。
  static const double detourFactor = 2;

  /// 乗換 2 回以上の案を出すには、乗換 1 回以下の案よりこれだけ速いこと（秒）。
  static const double multiTransferGainSeconds = 300;
  static const double detourAllowanceMeters = 2000;

  /// [record] の [board] から [alight] までのレグ（乗車中に降車停をずらしたときの線）。
  static ItineraryLeg legOf(RouteRecord record, int board, int alight) =>
      _Route.geometryOnly(record).leg(board, alight);

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

    final limit = Geo.distance(origin, destination) * detourFactor + detourAllowanceMeters;
    results.removeWhere((i) => i.walkMeters + i.rideMeters > limit);
    _dropDominated(results);
    _dropSlowMultiTransfers(results);
    results.sort((x, y) {
      final id = x.firstLeg.relationId.compareTo(y.firstLeg.relationId);
      if (id != 0) return id;
      return x.legs.length.compareTo(y.legs.length);
    });
    return results;
  }

  static double _seconds(LocalItinerary i) =>
      i.walkMeters / LocalItinerary.walkSpeed +
      i.rideMeters / LocalItinerary.busSpeed +
      i.transferCount * transferPenaltySeconds;

  /// 「A に少し乗って B に乗り換え…」のうち、B 以降に出発地からそのまま乗れる案があり、
  /// そちらが速いか同じなら、A を足した案は出さない（同じ道を走る路線の 1 停留所乗車が並ぶのを防ぐ）。
  static void _dropDominated(List<LocalItinerary> results) {
    String key(Iterable<ItineraryLeg> legs) => legs.map((l) => l.relationId).join('>');
    final best = <String, double>{};
    for (final i in results) {
      final k = key(i.legs);
      final s = _seconds(i);
      if (s < (best[k] ?? double.infinity)) best[k] = s;
    }
    results.removeWhere((i) {
      if (i.legs.length < 2) return false;
      final s = _seconds(i);
      for (var start = 1; start < i.legs.length; start++) {
        final tail = best[key(i.legs.skip(start))];
        if (tail != null && tail <= s) return true;
      }
      return false;
    });
  }

  /// 乗換 2 回以上は、乗換 1 回以下の一番速い案より [multiTransferGainSeconds] 以上速いときだけ残す。
  static void _dropSlowMultiTransfers(List<LocalItinerary> results) {
    final simple = [for (final i in results) if (i.transferCount <= 1) _seconds(i)];
    if (simple.isEmpty) return;
    final best = simple.reduce(math.min);
    results.removeWhere((i) => i.transferCount >= 2 && _seconds(i) > best - multiTransferGainSeconds);
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

  /// 概算時間が短い方。同じなら徒歩が短い方。
  static _Candidate _better(_Candidate? current, _Candidate next, List<_Route> routes) {
    if (current == null) return next;
    final a = next.cost(routes);
    final b = current.cost(routes);
    if (a != b) return a < b ? next : current;
    return next.walk < current.walk ? next : current;
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

  /// 概算の所要秒。
  double cost(List<_Route> routes) =>
      walk / LocalItinerary.walkSpeed +
      ride(routes) / LocalItinerary.busSpeed +
      (hops.length - 1) * LocalPlanner.transferPenaltySeconds;

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
    final n = record.stops.length;
    bestAlightAfter = List<int?>.filled(n, null);
    // 後ろから見て、区間 k 以降で目的地に一番近づく区間（同距離なら手前の区間）。
    int? closest;
    var closestMeters = double.infinity;
    for (var k = n - 2; k >= 0; k--) {
      final d = _approachMeters(k, destination);
      if (d <= closestMeters) {
        closest = k;
        closestMeters = d;
      }
      bestAlightAfter[k] = _alightAround(closest!, after: k);
    }
  }

  /// 線と停留所だけを使う（出発地・目的地なし）。[leg] を作るためだけに使う。
  _Route.geometryOnly(this.record)
      : originDistance = const [],
        destinationDistance = const [] {
    boardIndex = null;
    bestAlightAfter = const [];
  }

  /// 最接近の区間 [segment] の前後の停留所のうち、目的地まで歩く距離が短い方（同距離なら手前）。
  /// 乗車停留所 [after] より後ろだけ。歩く距離が [LocalPlanner.alightRadiusMeters] を超えたら降りない。
  int? _alightAround(int segment, {required int after}) {
    final before = segment;
    final next = segment + 1;
    final pick = before <= after || destinationDistance[next] < destinationDistance[before] ? next : before;
    return destinationDistance[pick] <= LocalPlanner.alightRadiusMeters ? pick : null;
  }

  /// 目的地から区間 k → k+1 の線までの距離。目的地から遠い区間は停留所どうしの直線で見る
  /// （線の頂点探しを近くの区間だけにする）。
  double _approachMeters(int k, GeoPoint destination) {
    final a = record.stops[k].point;
    final b = record.stops[k + 1].point;
    final near = math.min(destinationDistance[k], destinationDistance[k + 1]);
    if (near > _detailedApproachMeters) return Geo.distanceToPolyline(destination, [a, b]);
    return Geo.distanceToPolyline(destination, [a, ..._span(k).via, b]);
  }

  /// これより目的地から遠い区間は、線の形を見ずに停留所どうしの直線で測る。
  static const double _detailedApproachMeters = 3000;

  final RouteRecord record;
  final List<double> originDistance;
  final List<double> destinationDistance;
  late final int? boardIndex;

  /// 添字 u で乗ったときの降車停留所。u より後ろで路線が目的地に一番近づく点の、
  /// 直前と直後の停留所のうち歩く距離が短い方（同距離なら手前）。
  late final List<int?> bestAlightAfter;

  late final List<GeoPoint> _flat = [for (final seg in record.polylineSegments) ...seg];

  /// [_flat] の辺 i → i+1 がセグメントの切れ目を繋いだだけの辺か。停留所はそこに投影しない。
  late final List<bool> _joins = () {
    final joins = List<bool>.filled(math.max(0, _flat.length - 1), false);
    var index = 0;
    for (final seg in record.polylineSegments) {
      if (index > 0 && seg.isNotEmpty) joins[index - 1] = true;
      index += seg.length;
    }
    return joins;
  }();
  late final List<double> _cumulative = () {
    final out = List<double>.filled(_flat.length, 0);
    for (var i = 1; i < _flat.length; i++) {
      out[i] = out[i - 1] + Geo.distance(_flat[i - 1], _flat[i]);
    }
    return out;
  }();
  final Map<int, _Span> _spans = {};

  /// 停留所がこれより線から離れていたら、線に乗っていないとみなす。
  static const double _onLineMeters = 120;

  /// 1 停留所あたりに残す線上の候補（線が同じ場所を何度も通るときの通過ごと）。
  static const int _maxAnchors = 6;

  static int? _nearest(List<double> distances, double radius) {
    int? best;
    for (var i = 0; i < distances.length; i++) {
      if (distances[i] <= radius && (best == null || distances[i] < distances[best])) best = i;
    }
    return best;
  }

  /// 停留所を線の辺へ投影した候補。線が同じ道を何度も通る（往復・ループ・環状）と候補は複数になる。
  /// 連続して近い辺の並びごとに一番近い 1 つを残す。
  List<_Anchor> _anchorsFor(GeoPoint p) {
    final n = _flat.length;
    if (n < 2) return const [];
    final scale = math.cos(p.latitude * math.pi / 180) * 111320;
    const latScale = 110574.0;
    final runs = <_Anchor>[];
    _Anchor? best;
    for (var i = 0; i + 1 < n; i++) {
      if (_joins[i]) {
        if (best != null) runs.add(best);
        best = null;
        continue;
      }
      final a = _flat[i];
      final b = _flat[i + 1];
      final ax = (a.longitude - p.longitude) * scale;
      final ay = (a.latitude - p.latitude) * latScale;
      final bx = (b.longitude - p.longitude) * scale;
      final by = (b.latitude - p.latitude) * latScale;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final px = ax + dx * t;
      final py = ay + dy * t;
      final offset = math.sqrt(px * px + py * py);
      if (offset > _onLineMeters) {
        if (best != null) runs.add(best);
        best = null;
        continue;
      }
      if (best == null || offset < best.offset) {
        final point = GeoPoint(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
        best = _Anchor(i, t, point, _cumulative[i] + (_cumulative[i + 1] - _cumulative[i]) * t, offset);
      }
    }
    if (best != null) runs.add(best);
    runs.sort((x, y) => x.offset.compareTo(y.offset));
    return runs.length > _maxAnchors ? runs.sublist(0, _maxAnchors) : runs;
  }

  /// 停留所ごとに、どの通過で線に乗っているか。隣どうしが線に沿って無理なく繋がる組を、
  /// 停留所列全体で選ぶ（前の区間で選んだ通過を次の区間でも使うので、ループで近道しない）。
  late final List<_Anchor?> _anchors = () {
    final stops = record.stops;
    final n = stops.length;
    final candidates = [for (final s in stops) <_Anchor?>[..._anchorsFor(s.point), null]];
    double emission(_Anchor? a) => a == null ? _offLinePenalty : a.offset * 4;
    var cost = [for (final a in candidates.first) emission(a)];
    final back = <List<int>>[];
    for (var k = 1; k < n; k++) {
      final straight = Geo.distance(stops[k - 1].point, stops[k].point);
      final next = <double>[];
      final from = <int>[];
      for (final q in candidates[k]) {
        var best = double.infinity;
        var arg = 0;
        for (var j = 0; j < candidates[k - 1].length; j++) {
          final c = cost[j] + _transition(candidates[k - 1][j], q, straight);
          if (c < best) {
            best = c;
            arg = j;
          }
        }
        next.add(best + emission(q));
        from.add(arg);
      }
      cost = next;
      back.add(from);
    }
    var pick = 0;
    for (var j = 1; j < cost.length; j++) {
      if (cost[j] < cost[pick]) pick = j;
    }
    final out = List<_Anchor?>.filled(n, null);
    for (var k = n - 1; k >= 0; k--) {
      out[k] = candidates[k][pick];
      if (k > 0) pick = back[k - 1][pick];
    }
    return out;
  }();

  static const double _offLinePenalty = 600;

  /// 線に沿った [p] → [q] の道のり。線をたどれない（離れすぎ・遠回りすぎ・同じ点）なら null。
  static double? _along(_Anchor? p, _Anchor? q, double straight) {
    if (p == null || q == null) return null;
    final along = (q.along - p.along).abs();
    if (along > straight * 3 + 300) return null;
    if (along < straight * 0.5 - 60) return null;
    return along;
  }

  /// 隣の停留所へ移るコスト。線の向きに進むのが一番安く、逆向きは割高、たどれなければ直線扱いで高い。
  static double _transition(_Anchor? p, _Anchor? q, double straight) {
    final along = _along(p, q, straight);
    if (along == null) return straight * 5 + 1000;
    return q!.along >= p!.along ? along : along * 1.5 + 100;
  }

  /// 隣り合う停留所 k → k+1 の区間。両端が線に乗っていて、道のりが直線の 3 倍 + 300m 以内なら、
  /// 線が逆向きでもそれをたどる。途中で数 km 飛んでいる線は道のりが伸びるので、停留所どうしを直接結ぶ。
  _Span _span(int k) => _spans.putIfAbsent(k, () {
        final straight = Geo.distance(record.stops[k].point, record.stops[k + 1].point);
        final p = _anchors[k];
        final q = _anchors[k + 1];
        final along = _along(p, q, straight);
        if (along == null) return _Span(straight, const []);
        return _Span(along, _trace(p!, q!));
      });

  /// 投影点 [p] から [q] まで、線の頂点を進む向きで返す（両端の投影点を含む）。
  List<GeoPoint> _trace(_Anchor p, _Anchor q) {
    final out = <GeoPoint>[p.point];
    if (q.along >= p.along) {
      for (var v = p.edge + 1; v <= q.edge; v++) {
        out.add(_flat[v]);
      }
    } else {
      for (var v = p.edge; v > q.edge; v--) {
        out.add(_flat[v]);
      }
    }
    out.add(q.point);
    return out;
  }

  double rideMeters(int board, int alight) {
    var total = 0.0;
    for (var k = board; k < alight; k++) {
      total += _span(k).meters;
    }
    return total;
  }

  /// 停留所と線の頂点をつないだ道のり。同じ場所の点は続けて入れない（方位がずれないように）。
  List<GeoPoint> path(int board, int alight) {
    final out = <GeoPoint>[record.stops[board].point];
    void add(GeoPoint p) {
      if (Geo.distance(out.last, p) >= 1) out.add(p);
    }

    for (var k = board; k < alight; k++) {
      for (final p in _span(k).via) {
        add(p);
      }
      add(record.stops[k + 1].point);
    }
    return out;
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

class _Span {
  const _Span(this.meters, this.via);
  final double meters;

  /// 停留所どうしのあいだにたどる線の点。空なら直線。
  final List<GeoPoint> via;
}

/// 停留所を線の辺 [edge]（[_Route._flat] の edge → edge+1）へ投影した点。
class _Anchor {
  const _Anchor(this.edge, this.t, this.point, this.along, this.offset);
  final int edge;
  final double t;
  final GeoPoint point;

  /// 線の始点からの道のり。
  final double along;

  /// 停留所から線までの距離。
  final double offset;
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
