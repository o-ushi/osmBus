import '../services/geo.dart';
import 'bus_identifier.dart';
import 'local_itinerary.dart';

/// 方位ヒント。[compassIndex] が null なら「向きはどちらでも可」。
class DirectionHint {
  const DirectionHint.any() : compassIndex = null;
  const DirectionHint.toward(int this.compassIndex);

  final int? compassIndex;

  bool get isAny => compassIndex == null;
}

sealed class BoardingDecision {
  const BoardingDecision();
}

/// まだ番号が入っていない。
class BoardingIdle extends BoardingDecision {
  const BoardingIdle();
}

/// 番号は入っているが、OSM データの利用に同意していない。
class BoardingConsentRequired extends BoardingDecision {
  const BoardingConsentRequired();
}

class BoardingNoLocation extends BoardingDecision {
  const BoardingNoLocation();
}

class BoardingNoDestination extends BoardingDecision {
  const BoardingNoDestination();
}

class BoardingNoRouteData extends BoardingDecision {
  const BoardingNoRouteData();
}

class BoardingCalculating extends BoardingDecision {
  const BoardingCalculating();
}

/// 見送る。
class DoNotBoard extends BoardingDecision {
  const DoNotBoard(this.input);
  final String input;
}

/// この系統なら乗ってよい。Swift の数字入力は 1 件でも variant 経路になる。
class BoardIfVariant extends BoardingDecision {
  const BoardIfVariant({
    required this.names,
    required this.itinerary,
    required this.direction,
  });

  /// §7 のソート順の系統 ref。
  final List<String> names;

  /// 採用した旅程。降車停留所と概算時間はここから出す。
  final LocalItinerary itinerary;
  final DirectionHint direction;

  String get alightStopName => itinerary.firstLeg.alightStop.name;
}

abstract final class BoardingJudge {
  static const double anyDirectionSpreadDegrees = 120;

  /// §9。[itineraries] は `LocalPlanner` の全旅程。
  static BoardingDecision decide(String input, List<LocalItinerary> itineraries) {
    final query = BusIdentifierParts.parse(input);
    if (query == null) return const BoardingIdle();

    final matched = itineraries
        .where((i) => BusIdentifierParts.refMatchesCompactNumber(i.firstLeg.ref, query.compactNumber))
        .toList();
    if (matched.isEmpty) return DoNotBoard(input);

    final anyDirect = matched.any((i) => i.transferCount == 0);
    final adopted = anyDirect ? matched.where((i) => i.transferCount == 0) : matched;

    final bestByRef = <String, LocalItinerary>{};
    for (final itinerary in adopted) {
      final ref = itinerary.firstLeg.ref;
      final current = bestByRef[ref];
      if (current == null || LocalItinerary.compareByWalk(itinerary, current) < 0) {
        bestByRef[ref] = itinerary;
      }
    }

    final names = BusIdentifierParts.sortTokens(bestByRef.keys);
    final best = bestByRef.values.reduce(
      (a, b) => LocalItinerary.compareByWalk(b, a) < 0 ? b : a,
    );
    final bearings = bestByRef.values.map((i) => i.bearing).toList();
    final direction = bearings.length >= 2 &&
            Geo.circularSpread(bearings) > anyDirectionSpreadDegrees
        ? const DirectionHint.any()
        : DirectionHint.toward(Geo.compassIndex(Geo.circularMean(bearings)));

    return BoardIfVariant(names: names, itinerary: best, direction: direction);
  }
}
