import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';

/// Chasers rail + Phase 1 heat scoring — off until explicitly enabled.
abstract final class MarketChasersConfig {
  /// Show the Chasers horizontal rail from fixture rows (non-live dev).
  static const bool enableChasersRail = bool.fromEnvironment(
    'MARKET_CHASERS_RAIL',
    defaultValue: false,
  );

  /// Phase 1 identity-level heat scoring via IP-specific gateway probes.
  static const bool enablePhase1Scoring = bool.fromEnvironment(
    'MARKET_CHASERS_SCORING',
    defaultValue: false,
  );

  /// IP-specific probes per refresh (rate-limited).
  static const int maxProbesPerRefresh = 8;

  static const int probePageSize = 12;

  static const int maxRailEntries = 8;

  static const Duration probeDelay = Duration(milliseconds: 120);

  /// Concurrent IP probes per batch — keeps gateway load disciplined.
  static const int probeConcurrency = 2;

  static const Duration memoryRefreshTtl = Duration(hours: 12);

  /// Show cached chasers from disk when younger than this (even if revalidating).
  static const Duration diskStaleTtl = Duration(days: 7);

  /// High-signal brand|ip probe keys — earlier batches hydrate the rail faster.
  static const List<String> probePriorityKeys = [
    'pop_mart|the_monsters',
    'pop_mart|skullpanda',
    'pop_mart|crybaby',
    'pop_mart|dimoo',
    'pop_mart|molly',
    'finding_unicorn|any_ip',
    'toycity|any_ip',
    '52toys|any_ip',
  ];

  /// Fixture rail when not on live eBay.
  static bool get showFixtureRail =>
      enableChasersRail && !MarketGatewayConfig.isActive;

  /// Reserve the Chasers slot while probing or when results are ready.
  static bool showLiveChasersSlot({
    required bool isLoading,
    required int entryCount,
  }) =>
      enablePhase1Scoring &&
      MarketGatewayConfig.isActive &&
      (isLoading || entryCount > 0);
}
