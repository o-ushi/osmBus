import '../models/official_stop_order.dart';
import '../models/route_catalog.dart';
import 'geo.dart';
import 'stop_order_repair.dart';

/// 公式の停留所順と OSM の路線を、自信があるときだけ対応させた結果。
class OfficialOrderMatch {
  const OfficialOrderMatch({required this.official, required this.orderedIds, required this.pairCount});

  /// 対応させた公式の 1 方向。
  final OfficialRoute official;

  /// OSM の停留所 ID を公式の順に並べたもの（対応しなかった OSM の停留所も線の順で差し込んである）。
  final List<int> orderedIds;
  final int pairCount;
}

/// 停留所の前後の違い。[before] なら [anchor] の手前、そうでなければ次。名前が null は「なし」。
class OrderHintLine {
  const OrderHintLine({required this.anchor, required this.before, required this.current, required this.official});

  final String anchor;
  final bool before;
  final String? current;
  final String? official;
}

/// 公式の停留所順（名前と座標）を、OSM の停留所に対応させる。対応させるのは自信があるときだけ。
///
/// - 系統は `ref` が同じもの（大文字小文字と前後の空白だけ無視。`E05` と `05` は別）。
/// - 公式の 1 件と OSM の 1 件は、正規化した名前が一致するか短い方が長い方に含まれ、
///   かつ [pairMeters] 以内のときだけ組にする。近い組から 1 対 1 で取る。
///   公式側の名前が空（非公式 GTFS の仮名を落としたもの）なら、名前は見ず座標だけで組にする。
/// - 組が [minPairs] 未満、または OSM 側と公式側の少ない方の半分未満なら自信なし。
/// - 組を公式の順に見て、線の上で [backtrackMeters] 以上戻るものがあれば方向違い。
/// - 方向は組の多い方。条件を満たす方向が 2 つあり、組の数が同程度なら対応しない。
abstract final class OfficialOrderMatcher {
  static const double pairMeters = 150;
  static const double backtrackMeters = 1000;
  static const int minPairs = 4;

  /// 2 方向の組の数の比がこれ以上なら「同程度」とみなす。
  static const double ambiguousRatio = 0.9;

  static String normalizeRef(String ref) => ref.trim().toUpperCase();

  static OfficialOrderMatch? match(RouteRecord route, List<OfficialRoute> official) {
    final ref = normalizeRef(route.ref);
    final candidates = [for (final o in official) if (normalizeRef(o.ref) == ref) o];
    if (candidates.isEmpty || route.stops.length < 2) return null;
    // 同じ停留所が 2 度出る路線は ID の順で表せない。
    if (route.stops.map((s) => s.id).toSet().length != route.stops.length) return null;
    final line = RouteLine.of(route.polylineSegments);
    if (line == null) return null;
    final along = [for (final s in route.stops) line.project(s.point).along];

    final viable = <(OfficialRoute, List<(int, int)>)>[];
    for (final candidate in candidates) {
      final pairs = _pairs(route.stops, candidate.stops);
      if (!_confident(pairs.length, route.stops.length, candidate.stops.length)) continue;
      if (_backtracks([for (final (_, osm) in pairs) along[osm]])) continue;
      viable.add((candidate, pairs));
    }
    if (viable.isEmpty) return null;
    viable.sort((a, b) => b.$2.length.compareTo(a.$2.length));
    final best = viable.first;
    if (viable.length > 1 && viable[1].$2.length >= best.$2.length * ambiguousRatio) return null;

    return OfficialOrderMatch(
      official: best.$1,
      orderedIds: _order(route.stops, best.$2, along),
      pairCount: best.$2.length,
    );
  }

  static bool _confident(int pairs, int osmCount, int officialCount) {
    final smaller = osmCount < officialCount ? osmCount : officialCount;
    return pairs >= minPairs && pairs * 2 >= smaller;
  }

  static bool _backtracks(List<double> alongInOfficialOrder) {
    var furthest = double.negativeInfinity;
    for (final a in alongInOfficialOrder) {
      if (a < furthest - backtrackMeters) return true;
      if (a > furthest) furthest = a;
    }
    return false;
  }

  /// 名前が似ていて近い組を、近い順に 1 対 1 で取る。結果は公式の順の (公式の添字, OSM の添字)。
  static List<(int, int)> _pairs(List<RouteStop> osm, List<OfficialStop> official) {
    final osmNames = [for (final s in osm) normalizeName(s.name)];
    final candidates = <(int, int, double)>[];
    for (var i = 0; i < official.length; i++) {
      final name = normalizeName(official[i].name);
      for (var j = 0; j < osm.length; j++) {
        if (name.isNotEmpty && !namesMatch(name, osmNames[j])) continue;
        final d = Geo.distance(official[i].point, osm[j].point);
        if (d <= pairMeters) candidates.add((i, j, d));
      }
    }
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    final usedOfficial = <int>{};
    final usedOsm = <int>{};
    final pairs = <(int, int)>[];
    for (final (i, j, _) in candidates) {
      if (usedOfficial.contains(i) || usedOsm.contains(j)) continue;
      usedOfficial.add(i);
      usedOsm.add(j);
      pairs.add((i, j));
    }
    pairs.sort((a, b) => a.$1.compareTo(b.$1));
    return pairs;
  }

  /// 対応した OSM の停留所を公式の順に置き、対応しなかった停留所は線の上の位置で前後の対応済みの
  /// あいだ（先頭より前、末尾より後ろを含む）に、線の順で差し込む。
  static List<int> _order(List<RouteStop> stops, List<(int, int)> pairs, List<double> along) {
    final matched = [for (final (_, osm) in pairs) osm];
    final a = [for (final m in matched) along[m]];
    final k = matched.length;
    final matchedSet = matched.toSet();
    // バケット b は matched[b] の直後（-1 は先頭より前）。
    final buckets = <int, List<int>>{};
    for (var j = 0; j < stops.length; j++) {
      if (matchedSet.contains(j)) continue;
      final u = along[j];
      int? bucket;
      for (var i = 0; i + 1 < k; i++) {
        if (a[i] <= u && u < a[i + 1]) {
          bucket = i;
          break;
        }
      }
      if (bucket == null) {
        if (u < a.first) {
          bucket = -1;
        } else if (u >= a.last) {
          bucket = k - 1;
        } else {
          // 線の上で少し戻る組のあいだ。位置が u を超えない対応済みのうち一番先のものの後ろ。
          var best = 0;
          for (var i = 0; i < k; i++) {
            if (a[i] <= u && a[i] >= a[best]) best = i;
          }
          bucket = best;
        }
      }
      buckets.putIfAbsent(bucket, () => []).add(j);
    }
    for (final list in buckets.values) {
      list.sort((x, y) {
        final c = along[x].compareTo(along[y]);
        return c != 0 ? c : x.compareTo(y);
      });
    }
    return [
      for (final j in buckets[-1] ?? const <int>[]) stops[j].id,
      for (var i = 0; i < k; i++) ...[
        stops[matched[i]].id,
        for (final j in buckets[i] ?? const <int>[]) stops[j].id,
      ],
    ];
  }

  /// [ids] の順に並べた停留所。ID が 1 つでも無い、または数が合わなければ null（路線データが変わった）。
  static List<RouteStop>? reorder(RouteRecord route, List<int> ids) {
    if (ids.length != route.stops.length) return null;
    final byId = {for (final s in route.stops) s.id: s};
    if (byId.length != route.stops.length) return null;
    final out = <RouteStop>[];
    for (final id in ids) {
      final stop = byId[id];
      if (stop == null) return null;
      out.add(stop);
    }
    return out;
  }

  // MARK: - 名前

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

  /// 大文字小文字・前後の空白・ベトナム語のダイアクリティカルを無視した名前。
  static String normalizeName(String name) {
    final buffer = StringBuffer();
    for (final rune in name.trim().toLowerCase().runes) {
      // 分解形の結合文字（U+0300–U+036F）は落とす。
      if (rune >= 0x300 && rune <= 0x36F) continue;
      buffer.write(_fold[rune] ?? String.fromCharCode(rune));
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 正規化済みの名前が一致するか、短い方が長い方に含まれる。
  static bool namesMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    return a.length <= b.length ? b.contains(a) : a.contains(b);
  }

  // MARK: - ヒント

  /// [current] と [official] の並びの違いを、停留所 [anchorId] の前後で説明する。
  /// 前後が同じ（または [anchorId] が無い）ときは、最初に順が違う箇所の手前だけ。同じ並びなら空。
  static List<OrderHintLine> hint({
    required List<RouteStop> current,
    required List<RouteStop> official,
    int? anchorId,
  }) {
    if (_sameIds(current, official)) return const [];
    String? neighbor(List<RouteStop> list, int id, int step) {
      final i = list.indexWhere((s) => s.id == id);
      if (i < 0) return null;
      final n = i + step;
      return n >= 0 && n < list.length ? list[n].name : null;
    }

    List<OrderHintLine> around(RouteStop anchor) => [
          for (final before in [true, false])
            if (neighbor(current, anchor.id, before ? -1 : 1) != neighbor(official, anchor.id, before ? -1 : 1))
              OrderHintLine(
                anchor: anchor.name,
                before: before,
                current: neighbor(current, anchor.id, before ? -1 : 1),
                official: neighbor(official, anchor.id, before ? -1 : 1),
              ),
        ];

    final anchor = anchorId == null ? null : official.where((s) => s.id == anchorId).firstOrNull;
    if (anchor != null) {
      final lines = around(anchor);
      if (lines.isNotEmpty) return lines;
    }
    for (final stop in official) {
      final lines = around(stop).where((l) => l.before).toList();
      if (lines.isNotEmpty) return lines;
    }
    return const [];
  }

  static bool _sameIds(List<RouteStop> a, List<RouteStop> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}
