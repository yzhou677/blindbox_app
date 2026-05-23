import 'package:blindbox_app/features/market/application/alias_tokenizer.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_title_normalizer.dart';

/// Listing-title normalization for identity matching (single pipeline).
abstract final class MarketListingTitleNormalizer {
  static const Set<String> _noiseTokens = {
    'BNIB',
    'NIB',
    'SEALED',
    'MISB',
    'MIB',
    'OS',
    'NRFB',
    'V1',
    'V2',
    'V3',
    'VER',
    'VERSION',
  };

  /// Primary haystack for substring / token matching.
  static String normalizeForMatching(String raw) {
    var s = TaxonomyTitleNormalizer.normalize(raw);
    if (s.isEmpty) return '';

    final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final kept = parts.where((p) => !_noiseTokens.contains(p));
    return kept.join(' ');
  }

  static List<String> tokenize(String normalized) =>
      AliasTokenizer.tokenize(normalized);
}
