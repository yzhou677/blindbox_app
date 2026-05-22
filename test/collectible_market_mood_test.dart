import 'package:blindbox_app/features/market/application/collectible_market_mood_rules.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active mood when many sightings', () {
    expect(
      resolveMarketMood(
        listingCount: 4,
        avgPriceChangePercent: 0,
        anyHardToFind: false,
      ),
      MarketMood.active,
    );
  });

  test('calm mood for sparse stable sightings', () {
    expect(
      resolveMarketMood(
        listingCount: 2,
        avgPriceChangePercent: 0.5,
        anyHardToFind: false,
      ),
      MarketMood.calm,
    );
  });

  test('observed rarity when secret flag present', () {
    final rows = [
      MarketListing(
        id: 'x',
        hasSecretFigure: true,
        collectible: Collectible(
          id: 'x',
          name: 'Secret',
          series: 'S',
          brand: 'B',
          releaseDate: DateTime.utc(2026),
          imageUrl: '',
        ),
        currentPriceUsd: 1,
        priceChangePercent: 0,
        listingCount: 1,
      ),
    ];
    expect(resolveRarityPresence(rows), RarityPresence.observed);
  });
}
