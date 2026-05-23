import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_client.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/mappers/mercari_listing_mapper.dart';
import 'package:blindbox_app/features/market/application/market_sandbox_browse_install.dart';
import 'package:blindbox_app/features/market/data/source/mercari_sandbox_market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    MarketProviderBrowseCache.instance.clear(MarketProviderId.mercari);
    MarketBrowseListingsSession.instance.reset();
    CollectibleMarketSession.instance.reset();
    MercariSandboxMarketSource.lastFetchError = null;
  });

  test('gateway client parses emulator-shaped browse JSON', () async {
    final client = MercariGatewayClient(
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/blindbox-collection/us-central1/market/v1/browse',
        );
        return http.Response(
          '''
{
  "items": [
    {
      "id": "m90000000001",
      "title": "pop mart — cozy vinyl figure",
      "price": {"value": "24.00", "currency": "USD"},
      "image": {"imageUrl": "https://example.com/a.png"},
      "listingUrl": "https://www.mercari.com/us/item/m90000000001/"
    }
  ],
  "hasMore": false
}
''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final dto = await client.fetchBrowse(
      baseUrl: Uri.parse(
        'http://10.0.2.2:5001/blindbox-collection/us-central1/market',
      ),
    );
    expect(dto.items, hasLength(1));
    expect(dto.items.first.title, contains('pop mart'));
  });

  test('install merges mercari cache rows into browse session', () async {
    const dto = MercariListingDto(
      id: 'm90000000001',
      title: 'pop mart — cozy vinyl figure',
      priceValue: '24.00',
      currency: 'USD',
      imageUrl: 'https://example.com/a.png',
      listingUrl: 'https://www.mercari.com/us/item/m90000000001/',
    );

    await MarketProviderBrowseCache.instance.write(
      id: MarketProviderId.mercari,
      listings: [dto.toMarketListing()],
      wireJson: '{}',
      nextCursor: null,
      hasMore: false,
    );

    final asset = MarketListing(
      id: 'mkt-mock-1',
      providerId: MarketProviderId.mock.wireName,
      collectible: Collectible(
        id: 'c1',
        name: 'Puff Cloud',
        series: 'Sky Snuggles',
        brand: 'POP MART',
        releaseDate: DateTime.utc(2026),
        imageUrl: 'https://example.com/puff.png',
      ),
      currentPriceUsd: 44,
      priceChangePercent: 0,
      listingCount: 1,
    );

    installSandboxMarketBrowse(sessionRows: [asset]);

    final session = MarketBrowseListingsSession.instance.list;
    expect(session.length, 2);
    expect(
      session.any((e) => e.collectible.name.contains('pop mart')),
      isTrue,
    );
    expect(CollectibleMarketSession.instance.list.length, 2);
  });
}
