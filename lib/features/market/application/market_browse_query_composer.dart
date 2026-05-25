import 'package:blindbox_app/features/market/application/market_browse_search_anchor.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';

/// Parity mirror of gateway `composeBrowseUpstreamQ` for tests only.
///
/// Runtime retrieval sends facets to the gateway; upstream `q` is composed
/// server-side in `functions/src/providers/gateway/composeBrowseQuery.ts`.
abstract final class MarketBrowseQueryComposer {
  static const String defaultCollectibleTerms = 'blind box vinyl figure';

  /// IPs with live-verified eBay Character facet (must match gateway taxonomy).
  static const Set<String> verifiedCharacterIpIds = {
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

  static const Map<String, String> _brandPreferredQueryAnyIp = {
    'dreams_inc': 'sonny angel blind box',
  };

  static const Map<String, String> _verifiedCharacterSupplements = {
    'crybaby': 'Crybaby',
    'pucky': 'Pucky',
  };

  /// Builds the keyword string the gateway would use for upstream eBay `q`.
  static String composeUpstreamQ(MarketBrowseQuery query) {
    final search = query.searchText.trim();
    final terms = <String>[];

    if (query.brandId != MarketTaxonomyIds.anyBrand) {
      if (query.ipId == MarketTaxonomyIds.anyIp) {
        final anyIpQ = _brandPreferredQueryAnyIp[query.brandId];
        if (anyIpQ != null) {
          terms.add(anyIpQ);
        } else {
          final brandTerm = brandQueryTermFor(query.brandId);
          if (brandTerm != null) terms.add(brandTerm);
        }
      } else {
        final brandTerm = brandQueryTermFor(query.brandId);
        if (brandTerm != null) terms.add(brandTerm);
      }
    }

    if (query.ipId != MarketTaxonomyIds.anyIp &&
        !verifiedCharacterIpIds.contains(query.ipId)) {
      final ipTerm = _ipSearchTerm(query.ipId);
      if (ipTerm != null) terms.add(ipTerm);
    } else if (query.ipId != MarketTaxonomyIds.anyIp &&
        verifiedCharacterIpIds.contains(query.ipId)) {
      final supplement = _verifiedCharacterSupplements[query.ipId];
      if (supplement != null) terms.add(supplement);
    }

    if (search.isNotEmpty) {
      terms.add(
        MarketBrowseSearchAnchor.resolveSearchText(
          searchText: search,
          brandId: query.brandId,
          ipId: query.ipId,
        ),
      );
    }

    if (terms.isEmpty) return defaultCollectibleTerms;
    return terms.join(' ');
  }

  /// Gateway-aligned brand `q` token (parity tests + search-anchor helper).
  static String? brandQueryTermFor(String brandId) => _brandQueryTerms[brandId];

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
