import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/taxonomy/market_filter_visibility.dart';

/// Builds market/collection filter chip rows from a [CatalogSeedBundle] (Firestore ids).
abstract final class MarketCatalogFilters {
  static List<MarketBrandTaxon> brandsFromBundle(CatalogSeedBundle bundle) {
    final ipIdsByBrand = _ipIdsByBrand(bundle);
    final ipsByBrand = <String, List<String>>{};
    for (final ip in bundle.ips) {
      if (MarketFilterVisibility.hiddenIpIds.contains(ip.id)) continue;
      final brandIpIds = ipIdsByBrand[ip.brandId] ?? const {};
      if (!MarketFilterVisibility.shouldShowIpOnFilterRail(ip.id, brandIpIds)) continue;
      (ipsByBrand[ip.brandId] ??= []).add(ip.id);
    }

    final brandById = {for (final b in bundle.brands) b.id: b};
    final out = <MarketBrandTaxon>[];
    for (final entry in brandById.entries) {
      if (MarketFilterVisibility.hiddenBrandIds.contains(entry.key)) continue;
      final ips = ipsByBrand[entry.key] ?? const <String>[];
      if (ips.isEmpty) continue;
      out.add(
        MarketBrandTaxon(
          id: entry.key,
          displayLabel: entry.value.displayName,
          supportedIpIds: List<String>.unmodifiable(ips),
        ),
      );
    }
    out.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return out;
  }

  static List<MarketIpTaxon> ipsFromBundle(CatalogSeedBundle bundle) {
    final brandById = {for (final b in bundle.brands) b.id: b};
    final ipIdsByBrand = _ipIdsByBrand(bundle);
    final out = <MarketIpTaxon>[];
    for (final ip in bundle.ips) {
      if (MarketFilterVisibility.hiddenIpIds.contains(ip.id)) continue;
      if (MarketFilterVisibility.hiddenBrandIds.contains(ip.brandId)) continue;
      if (!brandById.containsKey(ip.brandId)) continue;
      final brandIpIds = ipIdsByBrand[ip.brandId] ?? const {};
      if (!MarketFilterVisibility.shouldShowIpOnFilterRail(ip.id, brandIpIds)) continue;
      out.add(MarketIpTaxon(id: ip.id, displayLabel: ip.displayName));
    }
    return out;
  }

  static Map<String, Set<String>> _ipIdsByBrand(CatalogSeedBundle bundle) {
    final out = <String, Set<String>>{};
    for (final ip in bundle.ips) {
      if (MarketFilterVisibility.hiddenIpIds.contains(ip.id)) continue;
      if (MarketFilterVisibility.hiddenBrandIds.contains(ip.brandId)) continue;
      (out[ip.brandId] ??= {}).add(ip.id);
    }
    return out;
  }
}
