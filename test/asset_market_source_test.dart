import 'package:blindbox_app/features/market/data/source/asset_market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AssetMarketSource loads bundled browse rows with mock provider id', () async {
    final source = AssetMarketSource();
    final listings = await source.fetchBrowseListings();

    expect(listings.length, greaterThan(10));
    expect(source.providerId, MarketProviderId.mock);
    expect(listings.first.providerId, MarketProviderId.mock.wireName);
    expect(listings.first.externalListingUrl, isNotNull);
    expect(
      listings.first.externalListingUrl,
      startsWith('https://market.example/listing/'),
    );
    expect(listings.first.providerListingId, isNotEmpty);
    expect(listings.first.taxonomyBrandId, isNotNull);
  });
}
