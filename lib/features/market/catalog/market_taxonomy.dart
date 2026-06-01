import 'package:blindbox_app/features/market/taxonomy/market_filter_visibility.dart';
import 'package:blindbox_app/features/market/taxonomy/market_taxonomy_adapter.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Sentinel ids for “no facet” filter selection (UI + future API parity).
abstract final class MarketTaxonomyIds {
  static const String anyBrand = 'any_brand';
  static const String anyIp = 'any_ip';
}

/// Single IP universe in the catalog (expand with API `ip` resources later).
@immutable
class MarketIpTaxon {
  const MarketIpTaxon({
    required this.id,
    required this.displayLabel,
  });

  final String id;
  final String displayLabel;
}

/// Brand with explicit IP coverage (mirrors licensor / label relationships).
@immutable
class MarketBrandTaxon {
  const MarketBrandTaxon({
    required this.id,
    required this.displayLabel,
    required this.supportedIpIds,
  });

  final String id;
  final String displayLabel;

  /// IP ids this brand carries in the in-app taxonomy (subset of [MarketTaxonomy.allIps]).
  final List<String> supportedIpIds;
}

/// Market browse taxonomy: filter chip rows and listing filter predicates.
///
/// Filter chips use the curated [MarketTaxonomyAdapter] registry only — not Firestore catalog.
/// [brandById] / [ipById] use the full adapter registry for listing copy and title resolution.
abstract final class MarketTaxonomy {
  static final List<MarketIpTaxon> _filterIps = [
    for (final row in MarketTaxonomyAdapter.buildFilterIpRows())
      MarketIpTaxon(id: row.id, displayLabel: row.displayLabel),
  ];

  static final List<MarketBrandTaxon> _filterBrands = [
    for (final row in MarketTaxonomyAdapter.buildFilterBrandRows())
      MarketBrandTaxon(
        id: row.id,
        displayLabel: row.displayLabel,
        supportedIpIds: row.supportedIpIds,
      ),
  ];

  static List<MarketIpTaxon> get allIps => _filterIps;
  static List<MarketBrandTaxon> get brands => _filterBrands;

  static MarketBrandTaxon? _filterBrandById(String id) {
    for (final b in _filterBrands) {
      if (b.id == id) return b;
    }
    return null;
  }

  static MarketIpTaxon? _filterIpById(String id) {
    for (final ip in _filterIps) {
      if (ip.id == id) return ip;
    }
    return null;
  }

  /// Full-registry IP lookup for market listing titles (not filter chips).
  static MarketIpTaxon? ipById(String id) {
    for (final row in MarketTaxonomyAdapter.buildIpRows()) {
      if (row.id == id) {
        return MarketIpTaxon(id: row.id, displayLabel: row.displayLabel);
      }
    }
    return null;
  }

  /// Full-registry brand lookup for market listing titles (not filter chips).
  static MarketBrandTaxon? brandById(String id) {
    for (final row in MarketTaxonomyAdapter.buildBrandRows()) {
      if (row.id == id) {
        return MarketBrandTaxon(
          id: row.id,
          displayLabel: row.displayLabel,
          supportedIpIds: row.supportedIpIds,
        );
      }
    }
    return null;
  }

  /// Brand row: Any + known brands.
  static List<({String id, String label})> brandChipOptions() => [
        (id: MarketTaxonomyIds.anyBrand, label: 'Any brand'),
        for (final b in brands) (id: b.id, label: b.displayLabel),
      ];

  /// IP row depends on brand: Any brand → all IPs; else only IPs under that brand.
  static List<({String id, String label})> ipChipOptionsForBrand(String brandId) {
    final ips = brandId == MarketTaxonomyIds.anyBrand
        ? allIps
        : _filterBrandById(brandId)
                ?.supportedIpIds
                .map(_filterIpById)
                .whereType<MarketIpTaxon>()
                .toList(growable: false) ??
            const <MarketIpTaxon>[];

    return [
      if (!MarketFilterVisibility.hideAnyIpForBrandIds.contains(brandId))
        (id: MarketTaxonomyIds.anyIp, label: 'Any IP'),
      for (final i in ips) (id: i.id, label: i.displayLabel),
    ];
  }

  /// Whether [ipId] is valid under [brandId] (Any values always valid).
  static bool ipAllowedForBrand(String brandId, String ipId) {
    if (ipId == MarketTaxonomyIds.anyIp) return true;
    if (brandId == MarketTaxonomyIds.anyBrand) return true;
    final b = _filterBrandById(brandId);
    return b != null && b.supportedIpIds.contains(ipId);
  }

  /// If the current IP is not sold under [brandId], reset to Any IP (or brand default).
  static String clampIpToBrand(String brandId, String ipId) {
    if (ipId == MarketTaxonomyIds.anyIp) {
      final defaultIp =
          MarketFilterVisibility.defaultIpWhenBrandSelected[brandId];
      if (defaultIp != null) return defaultIp;
    }
    if (ipAllowedForBrand(brandId, ipId)) return ipId;
    return MarketFilterVisibility.defaultIpWhenBrandSelected[brandId] ??
        MarketTaxonomyIds.anyIp;
  }

  /// Listing filter using stable taxonomy keys from each row (API-ready).
  static bool listingMatchesFilters(
    MarketListing m, {
    required String brandId,
    required String ipId,
  }) {
    if (brandId != MarketTaxonomyIds.anyBrand &&
        (m.taxonomyBrandId == null || m.taxonomyBrandId != brandId)) {
      return false;
    }
    if (ipId == MarketTaxonomyIds.anyIp) return true;
    if (m.taxonomyIpId == null) return false;
    return m.taxonomyIpId == ipId;
  }
}
