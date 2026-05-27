import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/source/asset_market_source.dart';
import 'package:blindbox_app/features/market/data/source/ebay_gateway_market_source.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';

/// Optional dev/demo fixture source.
///
/// Product builds should not show fixture/demo rows when live gateway is off.
const bool _enableMarketFixtureSource = bool.fromEnvironment(
  'MARKET_FIXTURE_SOURCE',
  defaultValue: false,
);

/// Production browse sources.
///
/// - Live gateway enabled: return eBay gateway source
/// - Live gateway disabled: return empty list (real product should show empty state,
///   never fixture/demo data)
/// - Fixture source can be opt-in for local development/tests via
///   `--dart-define=MARKET_FIXTURE_SOURCE=true`
List<MarketSource> productionMarketSources() {
  if (MarketGatewayConfig.isActive) {
    return [EbayGatewayMarketSource()];
  }
  if (_enableMarketFixtureSource) {
    return [AssetMarketSource()];
  }
  return const [];
}
