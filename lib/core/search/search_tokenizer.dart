import 'package:blindbox_app/core/search/search_normalizer.dart';

/// Whitespace tokenization after [SearchNormalizer].
abstract final class SearchTokenizer {
  /// Tokenizes [raw] after normalization. Empty → `[]`.
  static List<String> tokenize(String raw) =>
      tokenizeNormalized(SearchNormalizer.normalize(raw));

  /// Splits an already-normalized query string on spaces.
  static List<String> tokenizeNormalized(String normalized) {
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((e) => e.isNotEmpty).toList(growable: false);
  }
}
