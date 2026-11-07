import 'bus_identifier.dart';
import 'local_itinerary.dart';

enum TableSortMode { direction, distance, transfers }

enum DistanceMetric { walkFirst, total }

/// 番号表の 1 つの番号。
class MatrixEntry {
  const MatrixEntry({required this.token, required this.itinerary});

  final String token;
  final LocalItinerary itinerary;

  int get compassIndex => itinerary.compassIndex;
  int get column => itinerary.column;
  String get firstRef => itinerary.firstLeg.ref;

  /// 第 1 レグ以降の番号を `→` でつないだもの。
  String get chain =>
      itinerary.legs.map((l) => BusIdentifierParts.displayTokenForRef(l.ref)).join(' → ');
}

/// 方向基準の 1 行。[cells] は列 0 / 1 / 2+。
class MatrixRow {
  const MatrixRow({required this.compassIndex, required this.cells});

  final int compassIndex;
  final List<List<MatrixEntry>> cells;
}

/// §10 の番号表。
abstract final class BusMatrix {
  static const int columnCount = 3;

  /// 距離順の表で同じとみなす幅。
  static const double distanceBucketMeters = 100;

  static int _compareWalk(MatrixEntry a, MatrixEntry b) =>
      LocalItinerary.compareByWalk(a.itinerary, b.itinerary);

  /// 同じ方位の同じ番号は 1 つだけ。乗換の少ない列を優先し、同じ列なら徒歩合計、乗車距離の順で小さい方。
  static bool _better(MatrixEntry a, MatrixEntry b) {
    final column = a.column.compareTo(b.column);
    return column != 0 ? column < 0 : _compareWalk(a, b) < 0;
  }

  static List<MatrixEntry> _dedupe(List<LocalItinerary> itineraries) {
    final byKey = <String, MatrixEntry>{};
    final order = <String>[];
    for (final itinerary in itineraries) {
      final entry = MatrixEntry(
        token: BusIdentifierParts.displayTokenForRef(itinerary.firstLeg.ref),
        itinerary: itinerary,
      );
      final key = '${entry.compassIndex}|${entry.token}';
      final current = byKey[key];
      if (current == null) {
        order.add(key);
        byKey[key] = entry;
      } else if (_better(entry, current)) {
        byKey[key] = entry;
      }
    }
    return [for (final key in order) byKey[key]!];
  }

  static List<LocalItinerary> _byRelation(List<LocalItinerary> itineraries) =>
      [...itineraries]..sort((a, b) => a.firstLeg.relationId.compareTo(b.firstLeg.relationId));

  /// 行は方位。行の並びは relationId 昇順で方位が最初に現れた順。
  static List<MatrixRow> byDirection(List<LocalItinerary> itineraries) {
    final entries = _dedupe(_byRelation(itineraries));
    final rows = <int, List<List<MatrixEntry>>>{};
    for (final entry in entries) {
      rows.putIfAbsent(entry.compassIndex, () => List.generate(columnCount, (_) => []))[entry.column]
          .add(entry);
    }
    return [
      for (final MapEntry(key: compass, value: cells) in rows.entries)
        MatrixRow(
          compassIndex: compass,
          cells: [for (final cell in cells) cell..sort(_compareWalk)],
        ),
    ];
  }

  /// フラット表示（§10.3）。
  static List<MatrixEntry> flat(
    List<LocalItinerary> itineraries, {
    required TableSortMode mode,
    DistanceMetric metric = DistanceMetric.walkFirst,
  }) {
    final entries = _dedupe(_byRelation(itineraries));
    switch (mode) {
      case TableSortMode.transfers:
        entries.sort((a, b) {
          final column = a.column.compareTo(b.column);
          return column != 0 ? column : _compareWalk(a, b);
        });
      case TableSortMode.distance || TableSortMode.direction:
        // 数十 m の差で乗換 2 回の案が直通より上に来ないよう、100m 単位で比べてから乗換の少ない順。
        int bucket(double meters) => (meters / distanceBucketMeters).floor();
        int byTransfersThenRide(MatrixEntry a, MatrixEntry b) {
          final transfers = a.column.compareTo(b.column);
          return transfers != 0 ? transfers : a.itinerary.rideMeters.compareTo(b.itinerary.rideMeters);
        }
        if (metric == DistanceMetric.total) {
          entries.sort((a, b) {
            final total = bucket(a.itinerary.walkMeters + a.itinerary.rideMeters)
                .compareTo(bucket(b.itinerary.walkMeters + b.itinerary.rideMeters));
            return total != 0 ? total : byTransfersThenRide(a, b);
          });
        } else {
          entries.sort((a, b) {
            final walk = bucket(a.itinerary.walkMeters).compareTo(bucket(b.itinerary.walkMeters));
            return walk != 0 ? walk : byTransfersThenRide(a, b);
          });
        }
    }
    return entries;
  }
}
