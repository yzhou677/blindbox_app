import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blindbox_app/features/market/domain/market_listing_title_signals.dart';
import 'package:blindbox_app/models/collectible.dart';

MarketListing _listing(String title) {
  return MarketListing(
    id: 'mkt-test-${title.hashCode}',
    collectible: Collectible(
      id: 'c-${title.hashCode}',
      name: title,
      series: '',
      brand: '',
      releaseDate: DateTime.utc(2026),
      imageUrl: 'https://example.com/photo.jpg',
    ),
    currentPriceUsd: 20,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  test('presentationScore prefers clean figure over accessory lot', () {
    final clean = _listing('Pop Mart Labubu Macaron Figure');
    final accessory = _listing('Labubu Keychain Lot of 5');

    expect(
      MarketListingTitleSignals.presentationScore(clean),
      greaterThan(MarketListingTitleSignals.presentationScore(accessory)),
    );
  });

  test('isAccessory and isLot detect seller noise', () {
    expect(MarketListingTitleSignals.isAccessory('Labubu Keychain'), isTrue);
    expect(MarketListingTitleSignals.isLot('Lot of 10 Labubu'), isTrue);
    expect(MarketListingTitleSignals.isNoisy('custom inspired figure'), isTrue);
  });
}
