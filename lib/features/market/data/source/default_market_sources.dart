import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/asset_market_source.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';

/// Offline asset feed — used at startup and as the default provider list.
List<MarketSource> productionMarketSources() => [AssetMarketSource()];

/// Production sources plus optional live Mercari sandbox (manual refresh only).
List<MarketSource> sandboxMarketSources() {
  final sources = productionMarketSources();
  if (!MarketSandboxConfig.isActive) return sources;
  return [...sources, MercariSandboxMarketSource()];
}

/// @deprecated Use [productionMarketSources].
List<MarketSource> defaultMarketSources() => productionMarketSources();
