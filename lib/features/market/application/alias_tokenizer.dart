/// Tokenization helpers for listing-title identity matching.
abstract final class AliasTokenizer {
  static const Set<String> _stopwords = {
    'THE',
    'AND',
    'OR',
    'A',
    'AN',
    'OF',
    'FOR',
    'WITH',
    'FIGURE',
    'FIG',
    'FIGURES',
    'BLIND',
    'BOX',
    'SET',
    'LOT',
    'NEW',
    'USED',
    'SEALED',
    'BNIB',
    'NIB',
    'AUTH',
    'AUTHENTIC',
    'OFFICIAL',
    'POP',
    'MART',
    'V1',
    'V2',
    'V3',
    'VER',
    'VERSION',
  };

  /// Ordered unique tokens after stopword removal.
  static List<String> tokenize(String normalizedHaystack) {
    if (normalizedHaystack.isEmpty) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final part in normalizedHaystack.split(RegExp(r'\s+'))) {
      if (part.isEmpty) continue;
      if (_stopwords.contains(part)) continue;
      if (seen.add(part)) out.add(part);
    }
    return out;
  }
}
