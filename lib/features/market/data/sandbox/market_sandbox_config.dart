/// Feature-flagged live marketplace sandbox (default off).
abstract final class MarketSandboxConfig {
  static const bool enableLiveMercariSandbox = bool.fromEnvironment(
    'MARKET_SANDBOX_MERCARI',
    defaultValue: false,
  );

  static const String gatewayBaseUrl = String.fromEnvironment(
    'MERCARI_GATEWAY_BASE_URL',
    defaultValue: '',
  );

  static const int maxMercariItems = 24;
  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration cacheTtl = Duration(hours: 6);

  static bool get isActive {
    if (!enableLiveMercariSandbox) return false;
    return gatewayBaseUrl.trim().isNotEmpty;
  }

  static Uri? get gatewayUri {
    final raw = gatewayBaseUrl.trim();
    if (raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }
}
