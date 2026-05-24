import 'package:blindbox_app/features/market/application/market_browse_query_composer.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';

/// Parity mirror of gateway search anchoring for tests only.
abstract final class MarketBrowseSearchAnchor {
  static const _collectibleContextPhrases = [
    'blind box',
    'blind-box',
    'mystery box',
    'vinyl figure',
    'designer toy',
    'art toy',
    'sealed blind',
    'pop mart',
    'popmart',
  ];

  static const _brandPreferredQueryAnyIp = {
    'dreams_inc': 'sonny angel blind box',
  };

  static const _extraNativePhrases = [
    'cry baby',
    'tntspace dora',
    'tnt space dora',
    'liita',
    'may mei',
    'toptoy',
  ];

  static List<String>? _cachedNativePhrases;

  static String resolveSearchText({
    required String searchText,
    required String brandId,
    required String ipId,
  }) {
    final trimmed = searchText.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_shouldAnchor(trimmed, brandId, ipId)) {
      return '${MarketBrowseQueryComposer.defaultCollectibleTerms} $trimmed';
    }
    return trimmed;
  }

  static bool shouldAnchorDiscoverSearch(
    String search,
    String brandId,
    String ipId,
  ) =>
      _shouldAnchor(search, brandId, ipId);

  static bool isCollectibleNativeSearch(String search) =>
      _isCollectibleNativeSearch(search);

  static bool _shouldAnchor(String search, String brandId, String ipId) {
    final trimmed = search.trim();
    if (trimmed.isEmpty) return false;
    if (brandId != MarketTaxonomyIds.anyBrand ||
        ipId != MarketTaxonomyIds.anyIp) {
      return false;
    }
    if (_isCollectibleNativeSearch(trimmed)) return false;
    if (_searchContainsCollectibleContext(trimmed)) return false;
    return true;
  }

  static bool _searchContainsCollectibleContext(String search) {
    final norm = _normalize(search);
    if (norm.isEmpty) return false;
    if (norm == _normalize(MarketBrowseQueryComposer.defaultCollectibleTerms)) {
      return true;
    }
    for (final phrase in _collectibleContextPhrases) {
      if (_searchContainsPhrase(norm, phrase)) return true;
    }
    return false;
  }

  static bool _isCollectibleNativeSearch(String search) {
    final norm = _normalize(search);
    if (norm.isEmpty) return false;
    for (final phrase in _nativePhrases()) {
      if (_searchContainsPhrase(norm, phrase)) return true;
    }
    return false;
  }

  static List<String> _nativePhrases() {
    if (_cachedNativePhrases != null) return _cachedNativePhrases!;

    final raw = <String>{};
    void push(String? value) {
      final norm = _normalize(value ?? '');
      if (norm.isNotEmpty) raw.add(norm);
    }

    for (final brand in BrandTaxonomyRegistry.all) {
      push(brand.displayName);
      for (final alias in brand.aliases) {
        push(alias);
      }
      push(MarketBrowseQueryComposer.brandQueryTermFor(brand.id));
      push(_brandPreferredQueryAnyIp[brand.id]);
    }

    for (final ip in IpTaxonomyRegistry.all) {
      push(ip.displayName);
      for (final alias in ip.aliases) {
        push(alias);
      }
      for (final keyword in ip.searchKeywords) {
        push(keyword);
      }
    }

    // Dreams Inc studio lines share one brand row.
    push('Sonny Angel');
    push('Smiski');
    for (final phrase in _extraNativePhrases) {
      push(phrase);
    }

    final sorted = raw.toList()..sort((a, b) => b.length.compareTo(a.length));
    _cachedNativePhrases = sorted;
    return sorted;
  }

  static String _normalize(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _searchContainsPhrase(String norm, String phrase) {
    if (phrase.contains(' ')) return norm.contains(phrase);
    if (norm == phrase) return true;
    final escaped = RegExp.escape(phrase);
    return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(norm);
  }
}
