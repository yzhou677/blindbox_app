/// Marketplace provider identity for browse rows (data layer only).
enum MarketProviderId {
  /// Bundled / offline demo feed (provider-neutral wire JSON).
  mock,

  /// eBay Browse API or eBay-shaped wire payloads.
  ebay,

  /// Mercari (stub until Phase 2 integration).
  mercari,
}

extension MarketProviderIdX on MarketProviderId {
  String get wireName => name;
}

MarketProviderId marketProviderIdFromWire(String? raw) {
  if (raw == null || raw.isEmpty) return MarketProviderId.mock;
  for (final id in MarketProviderId.values) {
    if (id.name == raw) return id;
  }
  return MarketProviderId.mock;
}
