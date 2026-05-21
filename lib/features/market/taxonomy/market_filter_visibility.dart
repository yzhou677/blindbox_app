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
}
