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

  /// Rows per gateway page request.
  static const int pageSize = 24;

  /// Legacy alias — first-page fetch size.
  static const int maxMercariItems = pageSize;

  /// Maximum live Mercari rows merged into browse (calm cap, not infinite scroll).
  static const int maxMercariTotalRows = 72;

  static const int gatewayMaxAttempts = 3;
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration cacheTtl = Duration(hours: 6);
  static const Duration diskStaleTtl = Duration(days: 7);

  static Duration retryDelayForAttempt(int attempt) {
    final ms = 400 * (1 << attempt.clamp(0, 4));
    return Duration(milliseconds: ms);
  }

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
