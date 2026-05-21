/// Brand/IP ids hidden from market and collection filter chip rails only.
///
/// Full [BrandTaxonomyRegistry] / [IpTaxonomyRegistry] entries remain for title
/// resolution and listing taxonomy fields — do not remove from those registries.
abstract final class MarketFilterVisibility {
  static const Set<String> hiddenBrandIds = {
    'finding_unicorn',
  };

  static const Set<String> hiddenIpIds = {
    'peach_riot',
    'azura',
    'duckoo',
    'anmoo',
    'liila',
  };

  /// Parent IP chip suppressed when a more specific sibling IP is on the same brand rail.
  /// Canonical ids unchanged — filter UX only.
  static const Map<String, Set<String>> suppressParentIpWhenChildrenPresent = {
    'molly': {'baby_molly', 'space_molly'},
  };

  /// Whether [ipId] should appear on market/collection filter chip rails for [brandIpIds].
  static bool shouldShowIpOnFilterRail(String ipId, Set<String> brandIpIds) {
    final children = suppressParentIpWhenChildrenPresent[ipId];
    if (children == null) return true;
    return !children.any(brandIpIds.contains);
  }
}
