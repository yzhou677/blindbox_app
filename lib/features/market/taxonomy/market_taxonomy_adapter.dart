import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';

/// UI-facing taxonomy rows derived from curated registries (single source of truth).
///
/// Keeps widgets and [MarketTaxonomy] off raw registry types; expand coverage by editing
/// [BrandTaxonomyRegistry] / [IpTaxonomyRegistry] only.
abstract final class MarketTaxonomyAdapter {
  /// One row per IP in [IpTaxonomyRegistry.all] declaration order.
  static List<({String id, String displayLabel})> buildIpRows() => [
        for (final ip in IpTaxonomyRegistry.all)
          (id: ip.id, displayLabel: ip.displayName),
      ];

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
}
