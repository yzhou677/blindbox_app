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

/// Central catalog: brands ↔ IPs, chip rows, and listing filter predicates.
/// Replace const data with API-driven models when persistence lands.
abstract final class MarketTaxonomy {
  static const List<MarketIpTaxon> allIps = [
    MarketIpTaxon(id: 'hirono', displayLabel: 'Hirono'),
    MarketIpTaxon(id: 'labubu', displayLabel: 'Labubu'),
    MarketIpTaxon(id: 'skullpanda', displayLabel: 'Skullpanda'),
    MarketIpTaxon(id: 'liila', displayLabel: 'Liila'),
    MarketIpTaxon(id: 'nommi', displayLabel: 'Nommi'),
    MarketIpTaxon(id: 'lulu_piggy', displayLabel: 'LuLu the Piggy'),
  ];

  static const List<MarketBrandTaxon> brands = [
    MarketBrandTaxon(
      id: 'pop_mart',
      displayLabel: 'POP MART',
      supportedIpIds: ['hirono', 'labubu', 'skullpanda'],
    ),
    MarketBrandTaxon(
      id: 'toptoy',
      displayLabel: 'TOPTOY',
      supportedIpIds: ['nommi', 'lulu_piggy'],
    ),
    MarketBrandTaxon(
      id: 'tntspace',
      displayLabel: 'TNTSPACE',
      supportedIpIds: ['liila'],
    ),
  ];

  static MarketIpTaxon? ipById(String id) {
    for (final i in allIps) {
      if (i.id == id) return i;
    }
    return null;
  }

  static MarketBrandTaxon? brandById(String id) {
    for (final b in brands) {
      if (b.id == id) return b;
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
        : brandById(brandId)?.supportedIpIds
                .map((id) => ipById(id))
                .whereType<MarketIpTaxon>()
                .toList(growable: false) ??
            const <MarketIpTaxon>[];

    return [
      (id: MarketTaxonomyIds.anyIp, label: 'Any IP'),
      for (final i in ips) (id: i.id, label: i.displayLabel),
    ];
  }

  /// Whether [ipId] is valid under [brandId] (Any values always valid).
  static bool ipAllowedForBrand(String brandId, String ipId) {
    if (ipId == MarketTaxonomyIds.anyIp) return true;
    if (brandId == MarketTaxonomyIds.anyBrand) return true;
    final b = brandById(brandId);
    return b != null && b.supportedIpIds.contains(ipId);
  }

  /// If the current IP is not sold under [brandId], reset to Any IP.
  static String clampIpToBrand(String brandId, String ipId) {
    if (ipAllowedForBrand(brandId, ipId)) return ipId;
    return MarketTaxonomyIds.anyIp;
  }

  /// Listing filter using stable taxonomy keys from each row (API-ready).
  static bool listingMatchesFilters(
    MarketListing m, {
    required String brandId,
    required String ipId,
  }) {
    if (brandId != MarketTaxonomyIds.anyBrand && m.taxonomyBrandId != brandId) {
      return false;
    }
    if (ipId == MarketTaxonomyIds.anyIp) return true;
    if (m.taxonomyIpId == null) return false;
    return m.taxonomyIpId == ipId;
  }
}
