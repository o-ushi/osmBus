import 'dart:math' as math;

import '../models/route_catalog.dart';
import 'geo.dart';
import 'stop_order_repair.dart';

/// 停留所の名前の比較。前後の空白・連続する空白・大文字小文字・ベトナム語のダイアクリティカルだけを無視する。
/// 短い方が長い方に含まれるだけでは一致にしない。
abstract final class StopNames {
  static const Map<String, String> _plain = {
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };

  static final Map<int, String> _fold = {
    for (final MapEntry(:key, :value) in _plain.entries)
      for (final rune in key.runes) rune: value,
  };

  static String normalize(String name) {
    final buffer = StringBuffer();
    for (final rune in name.trim().toLowerCase().runes) {
      // 分解形の結合文字（U+0300–U+036F）は落とす。
      if (rune >= 0x300 && rune <= 0x36F) continue;
      buffer.write(_fold[rune] ?? String.fromCharCode(rune));
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool same(String a, String b) {
    final na = normalize(a);
    return na.isNotEmpty && na == normalize(b);
  }
}

/// 線の上で戻っている停留所 1 件。線に沿うと [after] と [before] のあいだ（null は線の端）。
class OrderBacktrack {
  const OrderBacktrack({required this.stop, required this.after, required this.before});

  final RouteStop stop;
  final RouteStop? after;
  final RouteStop? before;
}

/// 始点と終点が、繋いだ線の両端に乗っているかの所見。
/// [proposal] は、線の端に一番近い停留所を始点と終点にした並び。今と同じなら null。
class EndsFinding {
  const EndsFinding({
    required this.first,
    required this.firstMeters,
    required this.last,
    required this.lastMeters,
    required this.proposal,
  });

  final RouteStop first;
  final int firstMeters;
  final RouteStop last;
  final int lastMeters;
  final List<RouteStop>? proposal;
}

/// 順番の所見。[proposal] は `StopOrderRepair.repair` と同じ並べ替え。「これを使う」まで保存しない。
class OrderFinding {
  const OrderFinding({required this.backtracks, required this.partnerDisagrees, required this.proposal});

  final List<OrderBacktrack> backtracks;

  /// 復路と、線の向きを考慮しても前後が違う。
  final bool partnerDisagrees;
  final List<RouteStop> proposal;
}

/// 他の路線の停留所 1 件と、この路線の線からの距離。
class StopCandidate {
  const StopCandidate({required this.stop, required this.lineMeters, required this.routeRef});

  final RouteStop stop;
  final double lineMeters;

  /// その停留所が入っている路線の番号。
  final String routeRef;
}

/// 線から離れた停留所 1 件。[replacement] があるときだけ差し替えを出せる。
class PlaceFinding {
  const PlaceFinding({required this.index, required this.stop, required this.lineMeters, this.replacement});

  /// 表示の何番目か。
  final int index;
  final RouteStop stop;
  final int lineMeters;
  final StopCandidate? replacement;
}

/// 停留所の過不足。どれも見出しと一覧だけで、自動では足さない・消さない。
class MembershipFinding {
  const MembershipFinding({this.fromPartner = const [], this.fromOthers = const [], this.onlyHere = const []});

  final List<StopCandidate> fromPartner;
  final List<StopCandidate> fromOthers;
  final List<RouteStop> onlyHere;

  bool get isEmpty => fromPartner.isEmpty && fromOthers.isEmpty && onlyHere.isEmpty;
}

class RouteReview {
  const RouteReview({
    required this.route,
    required this.partner,
    required this.order,
    required this.ends,
    required this.places,
    required this.membership,
  });

  /// 確かめた路線（表示用の停留所）。
  final RouteRecord route;
  final RouteRecord? partner;
  final OrderFinding? order;
  final EndsFinding? ends;
  final List<PlaceFinding> places;
  final MembershipFinding membership;
}

/// ユーザーが「この路線を確認」を押したときだけ、所見を作る。線・往復・他路線と比べた差だけを出す。
abstract final class RouteReviewer {
  static const double onLineMeters = StopOrderRepair.onLineMeters;
  static const double backtrackMeters = StopOrderRepair.backtrackMeters;
  static const double replaceFarMeters = 150;
  static const double nearLineMeters = 50;
  static const double coveredMeters = 80;
  static const int listLimit = 8;

  static String normalizeRef(String ref) => ref.trim().toUpperCase();

  /// [route] は表示用の停留所を持つ路線。[catalog] はカタログの全路線（[route] 自身を含んでよい）。
  static RouteReview review(RouteRecord route, List<RouteRecord> catalog) {
    final others = [for (final r in catalog) if (r.relationId != route.relationId) r];
    final partner = partnerOf(route, others);
    final line = RouteLine.of(route.polylineSegments);
    return RouteReview(
      route: route,
      partner: partner,
      order: line == null ? null : _order(route, line, partner),
      ends: _ends(route),
      places: line == null ? const [] : _places(route, line, others),
      membership: _membership(route, line, partner, others),
    );
  }

  /// 比べる相手。同じ ref で、始点と終点が入れ替わっている路線。無ければ停留所 ID を一番多く共有する 1 本。
  /// 共有数が同点なら相手は無し。
  static RouteRecord? partnerOf(RouteRecord route, List<RouteRecord> others) {
    final ref = normalizeRef(route.ref);
    final candidates = [
      for (final r in others)
        if (r.relationId != route.relationId && normalizeRef(r.ref) == ref) r,
    ];
    if (candidates.isEmpty) return null;
    bool named(String? s) => s != null && s.trim().isNotEmpty;
    final swapped = [
      for (final r in candidates)
        if (named(route.from) && named(route.to) && named(r.from) && named(r.to) &&
            StopNames.same(r.from!, route.to!) && StopNames.same(r.to!, route.from!))
          r,
    ];
    if (swapped.length == 1) return swapped.single;
    return _mostShared(route, swapped.isNotEmpty ? swapped : candidates);
  }

  static RouteRecord? _mostShared(RouteRecord route, List<RouteRecord> candidates) {
    final ids = {for (final s in route.stops) s.id};
    RouteRecord? best;
    var bestCount = 0;
    var tie = false;
    for (final r in candidates) {
      final count = {for (final s in r.stops) s.id}.intersection(ids).length;
      if (count > bestCount) {
        best = r;
        bestCount = count;
        tie = false;
      } else if (count == bestCount && count > 0) {
        tie = true;
      }
    }
    return tie || bestCount == 0 ? null : best;
  }

  // MARK: - 順番

  static OrderFinding? _order(RouteRecord route, RouteLine line, RouteRecord? partner) {
    final stops = route.stops;
    if (stops.map((s) => s.id).toSet().length != stops.length) return null;
    final projections = [for (final s in stops) line.project(s.point)];
    final backIndices = <int>[];
    var furthest = double.negativeInfinity;
    for (var i = 0; i < stops.length; i++) {
      final p = projections[i];
      if (!p.onLine) continue;
      if (p.along < furthest - backtrackMeters) backIndices.add(i);
      furthest = math.max(furthest, p.along);
    }
    if (backIndices.isEmpty) return null;
    final repaired = StopOrderRepair.repair(route, lowAlongFirst: _lowAlongFirst(route));
    if (identical(repaired, route)) return null;

    final onLine = [for (var i = 0; i < stops.length; i++) if (projections[i].onLine) i]
      ..sort((a, b) => projections[a].along.compareTo(projections[b].along));
    final backtracks = <OrderBacktrack>[];
    for (final i in backIndices) {
      final k = onLine.indexOf(i);
      backtracks.add(OrderBacktrack(
        stop: stops[i],
        after: k > 0 ? stops[onLine[k - 1]] : null,
        before: k + 1 < onLine.length ? stops[onLine[k + 1]] : null,
      ));
    }
    return OrderFinding(
      backtracks: backtracks,
      partnerDisagrees: partner != null && _partnerDisagrees(stops, partner.stops),
      proposal: repaired.stops,
    );
  }

  /// 共有している停留所 ID の並びを、相手側を逆にして比べる。共有が 2 件未満なら比べない。
  static bool _partnerDisagrees(List<RouteStop> stops, List<RouteStop> partnerStops) {
    final partnerIds = {for (final s in partnerStops) s.id};
    final ids = {for (final s in stops) s.id};
    final mine = [for (final s in stops) if (partnerIds.contains(s.id)) s.id];
    final seen = <int>{};
    final theirs = [
      for (final s in partnerStops.reversed)
        if (ids.contains(s.id) && seen.add(s.id)) s.id,
    ];
    if (mine.length < 2) return false;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return true;
    }
    return false;
  }

  // MARK: - 始点と終点

  /// 接している区間を一本にした線の両端に、始点と終点の停留所が乗っているか。
  /// 端に停留所が無い線や、始点と終点が同じ一周は、所見を出さない。
  static EndsFinding? _ends(RouteRecord route) {
    final stops = route.stops;
    if (stops.length < 2) return null;
    final chain = RouteLine.longestChain(route.polylineSegments);
    if (chain == null || chain.length < 2) return null;
    final start = chain.first;
    final end = chain.last;
    if (Geo.distance(start, end) <= RouteLine.snapMeters) return null;
    bool covers(RouteStop stop, GeoPoint tip) => Geo.distance(stop.point, tip) <= onLineMeters;
    if (!stops.any((s) => covers(s, start)) || !stops.any((s) => covers(s, end))) return null;
    final firstTip = Geo.distance(stops.first.point, start) <= Geo.distance(stops.first.point, end) ? start : end;
    final lastTip = Geo.distance(stops.last.point, start) <= Geo.distance(stops.last.point, end) ? start : end;
    final firstMeters = Geo.distance(stops.first.point, firstTip).round();
    final lastMeters = Geo.distance(stops.last.point, lastTip).round();
    final sameTip = Geo.distance(firstTip, lastTip) <= RouteLine.snapMeters;
    if (!sameTip && firstMeters <= onLineMeters && lastMeters <= onLineMeters) return null;

    final line = RouteLine.of([chain]);
    if (line == null) return null;
    final projections = [for (final stop in stops) line.project(stop.point)];
    final onLine = [for (var i = 0; i < stops.length; i++) if (projections[i].onLine) i]
      ..sort((a, b) => projections[a].along.compareTo(projections[b].along));
    if (onLine.length < 2) return null;
    final startAlong = line.project(start).along;
    final preferredStart = _lowAlongFirst(route) ? startAlong : line.project(end).along;
    if ((projections[onLine.first].along - preferredStart).abs() > (projections[onLine.last].along - preferredStart).abs()) {
      final reversed = onLine.reversed.toList();
      onLine
        ..clear()
        ..addAll(reversed);
    }
    final sequence = [for (final i in onLine) stops[i]];
    for (var i = 0; i < stops.length; i++) {
      if (projections[i].onLine) continue;
      var bestK = 0;
      var bestDelta = double.infinity;
      for (var k = 0; k < sequence.length; k++) {
        final delta = (line.project(sequence[k].point).along - projections[i].along).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          bestK = k;
        }
      }
      final at = bestK >= sequence.length - 1 ? sequence.length - 1 : bestK + 1;
      sequence.insert(at, stops[i]);
    }
    final same = sequence.length == stops.length &&
        [for (var i = 0; i < stops.length; i++) sequence[i].id == stops[i].id].every((ok) => ok);
    return EndsFinding(
      first: stops.first,
      firstMeters: firstMeters,
      last: stops.last,
      lastMeters: lastMeters,
      proposal: same ? null : sequence,
    );
  }

  /// 繋いだ線の始まり（along が小さい側）を始点にするか。
  /// 方面の名前がどちらの端の停留所に近いかで決める。名前が無ければ、今の始点に近い端。
  static bool _lowAlongFirst(RouteRecord route) {
    final chain = RouteLine.longestChain(route.polylineSegments);
    if (chain == null || chain.length < 2) return true;
    final start = chain.first;
    final end = chain.last;
    if (Geo.distance(start, end) <= RouteLine.snapMeters) return true;
    double named(String? label, GeoPoint tip) {
      final text = StopNames.normalize(label ?? '');
      if (text.length < 3) return double.infinity;
      var best = double.infinity;
      for (final stop in route.stops) {
        if (!StopNames.normalize(stop.name).contains(text)) continue;
        best = math.min(best, Geo.distance(stop.point, tip));
      }
      return best;
    }

    final fromStart = named(route.from, start);
    final fromEnd = named(route.from, end);
    if (fromStart != fromEnd) return fromStart < fromEnd;
    final toStart = named(route.to, start);
    final toEnd = named(route.to, end);
    if (toStart != toEnd) return toEnd < toStart;
    return Geo.distance(route.stops.first.point, start) <= Geo.distance(route.stops.first.point, end);
  }

  // MARK: - 場所

  static List<PlaceFinding> _places(RouteRecord route, RouteLine line, List<RouteRecord> others) {
    final shownIds = {for (final s in route.stops) s.id};
    final findings = <PlaceFinding>[];
    for (final (i, stop) in route.stops.indexed) {
      final distance = line.project(stop.point).distance;
      if (distance <= onLineMeters) continue;
      StopCandidate? best;
      for (final other in others) {
        for (final c in other.stops) {
          if (c.id <= 0 || shownIds.contains(c.id)) continue;
          if (!StopNames.same(c.name, stop.name)) continue;
          if (Geo.distance(c.point, stop.point) <= replaceFarMeters) continue;
          final d = line.project(c.point).distance;
          if (d > onLineMeters) continue;
          if (best == null || d < best.lineMeters) {
            best = StopCandidate(stop: c, lineMeters: d, routeRef: other.ref);
          }
        }
      }
      findings.add(PlaceFinding(index: i, stop: stop, lineMeters: distance.round(), replacement: best));
    }
    return findings;
  }

  // MARK: - 過不足

  static MembershipFinding _membership(
    RouteRecord route,
    RouteLine? line,
    RouteRecord? partner,
    List<RouteRecord> others,
  ) {
    final shown = route.stops;
    final shownIds = {for (final s in shown) s.id};
    bool covered(RouteStop c, List<RouteStop> by) => by.any((s) => Geo.distance(s.point, c.point) <= coveredMeters);

    final box = _Box.around(route.polylineSegments, nearLineMeters);

    List<StopCandidate> near(Iterable<RouteRecord> routes, Set<int> skip) {
      if (line == null || box == null) return const [];
      final out = <int, StopCandidate>{};
      for (final r in routes) {
        for (final c in r.stops) {
          if (c.id <= 0 || shownIds.contains(c.id) || skip.contains(c.id) || out.containsKey(c.id)) continue;
          if (!box.contains(c.point)) continue;
          final d = line.project(c.point).distance;
          if (d > nearLineMeters || covered(c, shown)) continue;
          out[c.id] = StopCandidate(stop: c, lineMeters: d, routeRef: r.ref);
        }
      }
      return (out.values.toList()..sort((a, b) => a.lineMeters.compareTo(b.lineMeters))).take(listLimit).toList();
    }

    final fromPartner = partner == null ? const <StopCandidate>[] : near([partner], const {});
    final fromOthers = near(
      [for (final r in others) if (r.relationId != partner?.relationId) r],
      {for (final c in fromPartner) c.stop.id},
    );

    var onlyHere = const <RouteStop>[];
    if (partner != null) {
      final partnerIds = {for (final s in partner.stops) s.id};
      final list = [
        for (final s in shown)
          if (!partnerIds.contains(s.id) && !covered(s, partner.stops)) s,
      ];
      if (line != null) {
        final d = {for (final s in list) s.id: line.project(s.point).distance};
        list.sort((a, b) => d[a.id]!.compareTo(d[b.id]!));
      }
      onlyHere = list.take(listLimit).toList();
    }
    return MembershipFinding(fromPartner: fromPartner, fromOthers: fromOthers, onlyHere: onlyHere);
  }
}

/// 線を囲む緯度経度の箱。遠い停留所を線へ落とす前に外す。
class _Box {
  const _Box(this.south, this.north, this.west, this.east);

  final double south;
  final double north;
  final double west;
  final double east;

  static _Box? around(List<List<GeoPoint>> segments, double meters) {
    final points = [for (final s in segments) ...s];
    if (points.isEmpty) return null;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    final dLat = meters / 110574 * 1.5;
    final dLon = dLat / math.max(0.1, math.cos(south * math.pi / 180));
    return _Box(south - dLat, north + dLat, west - dLon, east + dLon);
  }

  bool contains(GeoPoint p) =>
      p.latitude >= south && p.latitude <= north && p.longitude >= west && p.longitude <= east;
}
