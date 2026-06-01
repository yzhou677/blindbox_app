import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/market_filter_visibility.dart';

/// UI-facing taxonomy rows derived from curated registries (single source of truth).
///
/// Filter chip rails use [buildFilterIpRows] / [buildFilterBrandRows].
/// Lookups for listings and title resolution use the full registry via [buildIpRows] /
/// [buildBrandRows].
abstract final class MarketTaxonomyAdapter {
  /// One row per IP in [IpTaxonomyRegistry.all] declaration order.
  static List<({String id, String displayLabel})> buildIpRows() => [
        for (final ip in IpTaxonomyRegistry.all)
          (id: ip.id, displayLabel: ip.displayName),
      ];

  /// IPs shown on market filter chip rails (subset of [buildIpRows]).
  static List<({String id, String displayLabel})> buildFilterIpRows() {
    final byBrand = <String, Set<String>>{};
    for (final ip in IpTaxonomyRegistry.all) {
      (byBrand[ip.brandId] ??= {}).add(ip.id);
    }
    return [
      for (final ip in IpTaxonomyRegistry.all)
        if (!MarketFilterVisibility.hiddenIpIds.contains(ip.id))
          if (MarketFilterVisibility.shouldShowIpOnFilterRail(
            ip.id,
            byBrand[ip.brandId] ?? const {},
          ))
            (id: ip.id, displayLabel: ip.displayName),
    ];
  }

  /// One row per brand in [BrandTaxonomyRegistry.all] declaration order;
  /// [supportedIpIds] follow first occurrence in [IpTaxonomyRegistry.all].
  static List<
      ({
        String id,
        String displayLabel,
        List<String> supportedIpIds,
      })> buildBrandRows() {
    final byBrand = <String, List<String>>{};
    for (final ip in IpTaxonomyRegistry.all) {
      (byBrand[ip.brandId] ??= []).add(ip.id);
    }
    return [
      for (final b in BrandTaxonomyRegistry.all)
        (
          id: b.id,
          displayLabel: b.displayName,
          supportedIpIds: List<String>.unmodifiable(
            List<String>.from(byBrand[b.id] ?? const <String>[]),
          ),
        ),
    ];
  }

  /// Brands and per-brand IP ids for filter chip rails only.
  static List<
      ({
        String id,
        String displayLabel,
        List<String> supportedIpIds,
      })> buildFilterBrandRows() {
    return [
      for (final row in buildBrandRows())
        if (!MarketFilterVisibility.hiddenBrandIds.contains(row.id))
          (
            id: row.id,
            displayLabel: row.displayLabel,
            supportedIpIds: _filterRailIpIdsForBrand(row.supportedIpIds),
          ),
    ];
  }

  static List<String> _filterRailIpIdsForBrand(List<String> brandIpIds) {
    final brandIpIdSet = brandIpIds.toSet();
    return List<String>.unmodifiable([
      for (final ipId in brandIpIds)
        if (!MarketFilterVisibility.hiddenIpIds.contains(ipId))
          if (MarketFilterVisibility.shouldShowIpOnFilterRail(ipId, brandIpIdSet))
            ipId,
    ]);
  }
}
