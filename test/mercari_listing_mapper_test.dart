import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:blindbox_app/features/market/data/mappers/mercari_listing_mapper.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps provider wire to MarketListing without taxonomy hints', () {
    const dto = MercariListingDto(
      id: 'm123',
      title: 'LABUBU V3 SECRET',
      priceValue: '88.00',
      currency: 'USD',
      imageUrl: 'https://cdn.example/item.jpg',
      listingUrl: 'https://market.example/listing/m123',
    );

    final row = dto.toMarketListing();
    expect(row.providerId, MarketProviderId.mercari.wireName);
    expect(row.providerListingId, 'm123');
    expect(row.externalListingUrl, contains('market.example'));
    expect(row.taxonomyBrandId, isNull);
    expect(row.taxonomyIpId, isNull);
    expect(row.collectible.name, 'LABUBU V3 SECRET');
    expect(row.currentPriceUsd, 88);
  });
}
