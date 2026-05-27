import 'package:blindbox_app/features/market/data/source/default_market_sources.dart';
import 'package:blindbox_app/features/market/data/source/ebay_gateway_market_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('productionMarketSources does not include fixture source by default', () {
    final sources = productionMarketSources();
    // In tests and local dev without explicit dart-define flags, we should
    // never ship fixture/demo browse rows.
    expect(
      sources.whereType<EbayGatewayMarketSource>().length <= 1,
      isTrue,
    );
    // When gateway is off, list is intentionally empty. When on, the only
    // source should be eBay gateway (validated above).
    final hasNonGatewaySource = sources.any((s) => s is! EbayGatewayMarketSource);
    expect(hasNonGatewaySource, isFalse);
  });
}
