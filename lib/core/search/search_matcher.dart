/// Token-based AND matching for local search (Search V2).
abstract final class SearchMatcher {
  /// True when every [token] appears as a substring in [haystack].
  ///
  /// [haystack] must already be [SearchNormalizer]-normalized.
  static bool allTokensMatch(String haystack, List<String> tokens) {
    if (tokens.isEmpty) return false;
    for (final token in tokens) {
      if (token.isEmpty || !haystack.contains(token)) return false;
    }
    return true;
  }

  /// Earliest start index among [tokens] in [haystack] (for relevance ordering).
  ///
  /// Returns `0` when [tokens] is empty.
  static int earliestTokenIndex(String haystack, List<String> tokens) {
    var best = 1 << 30;
    for (final token in tokens) {
      final i = haystack.indexOf(token);
      if (i >= 0 && i < best) best = i;
    }
    return best == (1 << 30) ? 0 : best;
  }
}
