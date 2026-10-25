/// Swift の `parseBusIdentifierParts` / `extractBusTokens` / `busNumberVariants`
/// / `containsBusNumber` と同じ結果を返す番号の正規化。
class BusIdentifierParts {
  const BusIdentifierParts({
    required this.prefix,
    required this.number,
    required this.suffix,
    required this.compactNumber,
  });

  final String prefix;
  final String number;
  final String suffix;

  /// 数字部の先頭ゼロを除いた十進表記（`05` → `5`）。
  final String compactNumber;

  String get displayToken => '$prefix$number$suffix';

  bool get hasLetters => prefix.isNotEmpty || suffix.isNotEmpty;

  static final RegExp _tokenPattern = RegExp(r'([A-Z]{0,3}\d{1,4}[A-Z]{0,3})');
  static final RegExp _partsPattern = RegExp(r'^([A-Z]{0,3})(\d{1,4})([A-Z]{0,3})$');
  static final RegExp _zeroPaddedPattern = RegExp(r'^([A-Z]*?)0+([1-9]\d*)([A-Z]*)$');

  static BusIdentifierParts? parse(String raw) {
    final normalized = raw.trim().toUpperCase();
    final match = _partsPattern.firstMatch(normalized);
    if (match == null) return null;
    final number = match.group(2)!;
    final compact = int.tryParse(number);
    if (compact == null) return null;
    return BusIdentifierParts(
      prefix: match.group(1)!,
      number: number,
      suffix: match.group(3)!,
      compactNumber: compact.toString(),
    );
  }

  static List<BusIdentifierParts> extractTokens(String text) {
    final normalized = text.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    return _tokenPattern
        .allMatches(normalized)
        .map((m) => parse(m.group(1)!))
        .whereType<BusIdentifierParts>()
        .toList();
  }

  /// compactNumber の数値昇順、同じなら prefix、同じなら suffix。
  static int compareTokens(String lhs, String rhs) {
    final left = parse(lhs);
    final right = parse(rhs);
    if (left != null && right != null && left.compactNumber != right.compactNumber) {
      return int.parse(left.compactNumber).compareTo(int.parse(right.compactNumber));
    }
    final prefixOrder = (left?.prefix ?? '').compareTo(right?.prefix ?? '');
    if (prefixOrder != 0) return prefixOrder;
    final suffixOrder = (left?.suffix ?? '').compareTo(right?.suffix ?? '');
    if (suffixOrder != 0) return suffixOrder;
    return lhs.compareTo(rhs);
  }

  static List<String> sortTokens(Iterable<String> tokens) =>
      tokens.toList()..sort(compareTokens);

  static List<String> variants(String busNumber) {
    final normalized = busNumber.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final variants = <String>{normalized};
    final match = _zeroPaddedPattern.firstMatch(normalized);
    if (match != null) {
      variants.add('${match.group(1)}${match.group(2)}${match.group(3)}');
    }
    return variants.toList();
  }

  static bool containsBusNumber(String text, String busNumber) {
    final trimmedText = text.trim().toUpperCase();
    final trimmedNumber = busNumber.trim().toUpperCase();
    if (trimmedText.isEmpty || trimmedNumber.isEmpty) return false;
    if (trimmedText == trimmedNumber) return true;
    final pattern =
        RegExp('(?<![0-9A-Z])${RegExp.escape(trimmedNumber)}(?![0-9A-Z])');
    return pattern.hasMatch(trimmedText);
  }

  /// 番号表のセルに出す表示用トークン（§10.1）。
  static String displayTokenForRef(String ref) {
    if (ref.length <= 10 && !ref.contains(RegExp(r'\s'))) return ref;
    final tokens = extractTokens(ref);
    if (tokens.isEmpty) return ref;
    return tokens.firstWhere((t) => t.hasLetters, orElse: () => tokens.first).displayToken;
  }

  /// `ref` のいずれかのトークンの compactNumber が一致するか。
  static bool refMatchesCompactNumber(String ref, String compactNumber) =>
      extractTokens(ref).any((t) => t.compactNumber == compactNumber);
}

/// トップのテンキー入力。数字のみ、最大 4 桁（Swift の `BusNumberInput`）。
abstract final class BusNumberInput {
  static const int maxLength = 4;

  static bool canAppend(String digit, String current) =>
      current.length < maxLength && RegExp(r'^\d$').hasMatch(digit);
}
