import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';

/// Composes upstream eBay keyword queries from curated taxonomy + user text.
abstract final class MarketBrowseQueryComposer {
  static const String defaultCollectibleTerms = 'designer vinyl blind box figure';

  /// Builds the keyword string sent to the gateway / eBay Browse `q` parameter.
  static String composeUpstreamQ(MarketBrowseQuery query) {
    final search = query.searchText.trim();
    if (_useAspectFacets(query)) return search;

    final terms = <String>[];

    if (query.brandId != MarketTaxonomyIds.anyBrand) {
      final brandTerm = _brandSearchTerm(query.brandId);
      if (brandTerm != null) terms.add(brandTerm);
    }

    if (query.ipId != MarketTaxonomyIds.anyIp) {
      final ipTerm = _ipSearchTerm(query.ipId);
      if (ipTerm != null) terms.add(ipTerm);
    }

    if (search.isNotEmpty) terms.add(search);

    if (terms.isEmpty) return defaultCollectibleTerms;
    return terms.join(' ');
  }

  static bool _useAspectFacets(MarketBrowseQuery query) {
    if (query.brandId == MarketTaxonomyIds.anyBrand &&
        query.ipId == MarketTaxonomyIds.anyIp) {
      return true;
    }
    return query.brandId != MarketTaxonomyIds.anyBrand ||
        query.ipId != MarketTaxonomyIds.anyIp;
  }

  static String? _brandSearchTerm(String brandId) {
    for (final brand in BrandTaxonomyRegistry.all) {
      if (brand.id == brandId) return brand.displayName;
    }
    return null;
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
