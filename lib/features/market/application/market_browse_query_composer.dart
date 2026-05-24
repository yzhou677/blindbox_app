import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';

/// Composes upstream eBay keyword queries from curated taxonomy + user text.
///
/// Mirrors gateway [composeBrowseUpstreamQ] — `q` is primary retrieval; aspects
/// are server-side refinement only.
abstract final class MarketBrowseQueryComposer {
  static const String defaultCollectibleTerms = 'blind box vinyl figure';

  /// IPs with live-verified eBay Character facet (must match gateway taxonomy).
  static const Set<String> _verifiedCharacterIpIds = {
    'the_monsters',
    'hirono',
    'skullpanda',
    'crybaby',
    'molly',
    'pucky',
  };

  static const Map<String, String> _brandQueryTerms = {
    'pop_mart': 'pop mart',
    'dpl': 'cureplaneta',
    'rolife': 'rolife',
    'finding_unicorn': 'finding unicorn',
    'tntspace': 'tnt space',
    'toptoy': 'toptoy',
  };

  /// Builds the keyword string sent to the gateway / eBay Browse `q` parameter.
  static String composeUpstreamQ(MarketBrowseQuery query) {
    final search = query.searchText.trim();
    final terms = <String>[];

    if (query.brandId != MarketTaxonomyIds.anyBrand) {
      final brandTerm = _brandSearchTerm(query.brandId);
      if (brandTerm != null) terms.add(brandTerm);
    }

    if (query.ipId != MarketTaxonomyIds.anyIp &&
        !_verifiedCharacterIpIds.contains(query.ipId)) {
      final ipTerm = _ipSearchTerm(query.ipId);
      if (ipTerm != null) terms.add(ipTerm);
    }

    if (search.isNotEmpty) terms.add(search);

    if (terms.isEmpty) return defaultCollectibleTerms;
    return terms.join(' ');
  }

  static String? _brandSearchTerm(String brandId) {
    return _brandQueryTerms[brandId];
  }

  static String? _ipSearchTerm(String ipId) {
    for (final ip in IpTaxonomyRegistry.all) {
      if (ip.id == ipId) return _primaryIpAlias(ip);
    }
    return null;
  }

  /// Prefer a recognizable alias (e.g. LABUBU) over display label (THE MONSTERS).
  static String _primaryIpAlias(IpTaxonomy ip) {
    for (final alias in ip.aliases) {
      if (alias.toUpperCase() != ip.displayName.toUpperCase()) {
        return alias;
      }
    }
    return ip.displayName;
  }
}
