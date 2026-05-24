import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/asset_market_source.dart';
import 'package:blindbox_app/features/market/data/source/ebay_gateway_market_source.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';

/// Production browse sources — live gateway only when enabled; bundled asset otherwise.
List<MarketSource> productionMarketSources() {
  if (MarketGatewayConfig.isActive) {
    return [EbayGatewayMarketSource()];
  }
  return [AssetMarketSource()];
}

/// Production sources plus optional Mercari sandbox (paused — internal only).
List<MarketSource> sandboxMarketSources() {
  final sources = productionMarketSources();
  if (!MarketSandboxConfig.isActive) return sources;
  return [...sources, MercariSandboxMarketSource()];
}

/// @deprecated Use [productionMarketSources].
List<MarketSource> defaultMarketSources() => productionMarketSources();
