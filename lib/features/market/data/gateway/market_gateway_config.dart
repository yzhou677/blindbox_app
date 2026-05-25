/// Production eBay browse via Firebase market gateway (default off).
abstract final class MarketGatewayConfig {
  static const bool enableEbayGateway = bool.fromEnvironment(
    'MARKET_GATEWAY_EBAY',
    defaultValue: false,
  );

  /// Gateway function root, e.g. `https://…/market` or emulator `http://127.0.0.1:5001/…/market`.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'MARKET_GATEWAY_BASE_URL',
    defaultValue: '',
  );

  /// @deprecated Use [gatewayBaseUrl].
  static const String legacyMercariGatewayBaseUrl = String.fromEnvironment(
    'MERCARI_GATEWAY_BASE_URL',
    defaultValue: '',
  );

  static const int initialPageSize = 12;
  static const int pageSize = 12;
  static const int maxLiveRows = 72;
  static const int gatewayMaxAttempts = 3;
  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration cacheTtl = Duration(hours: 6);
  static const Duration diskStaleTtl = Duration(days: 7);

  static Duration retryDelayForAttempt(int attempt) {
    final ms = 400 * (1 << attempt.clamp(0, 4));
    return Duration(milliseconds: ms);
  }

  static bool get isActive {
    if (!enableEbayGateway) return false;
    return _resolvedBaseUrl.trim().isNotEmpty;
  }

  static String get _resolvedBaseUrl {
    final primary = gatewayBaseUrl.trim();
    if (primary.isNotEmpty) return primary;
    return legacyMercariGatewayBaseUrl.trim();
  }

  static Uri? get gatewayUri {
    final raw = _resolvedBaseUrl;
    if (raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }
}
