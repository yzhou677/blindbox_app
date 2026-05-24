import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/application/chasers_phase1_scorer.dart';
import 'package:blindbox_app/features/market/application/chasers_probe_targets.dart';
import 'package:blindbox_app/features/market/domain/market_title_clusterer.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _listing(String title, {String? seller, double price = 20}) {
  return MarketListing(
    id: 'mkt-test-${title.hashCode}',
    collectible: Collectible(
      id: 'c-${title.hashCode}',
      name: title,
      series: '',
      brand: '',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: price,
    priceChangePercent: 0,
    listingCount: 1,
    sellerUsername: seller,
  );
}

void main() {
  const target = ChasersProbeTarget(
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    brandLabel: 'POP MART',
    ipLabel: 'THE MONSTERS',
    hintTokens: ['labubu', 'Labubu', 'THE MONSTERS'],
  );

  test('scoreChaserCluster rejects accessory-heavy clusters', () {
    const cluster = MarketTitleCluster(
      clusterKey: 'cluster:labubu',
      label: 'Labubu',
      listingCount: 2,
      uniqueSellerCount: 2,
      noiseListingCount: 0,
      accessoryListingCount: 2,
      sampleTitles: ['Labubu Keychain', 'Labubu Pendant'],
      medianPriceUsd: 20,
    );
    expect(scoreChaserCluster(cluster), 0);
  });

  test('buildChaserEntriesFromProbe groups Labubu titles', () {
    final entries = buildChaserEntriesFromProbe(
      target: target,
      listings: [
        _listing(
          'Pop Mart Labubu Exciting Macaron Series Blind Box',
          seller: 'a',
        ),
        _listing(
          'AUTHENTIC POP MART Labubu Macaron Plush',
          seller: 'b',
        ),
        _listing('POP MART Dimoo World Figure', seller: 'c'),
      ],
    );
    expect(entries, isNotEmpty);
    expect(entries.first.identityLabel.toLowerCase(), contains('labubu'));
    expect(entries.first.uniqueSellerCount, 2);
  });

  test('buildChaserEntriesFromProbe prefers clean figure over accessory lot', () {
    final entries = buildChaserEntriesFromProbe(
      target: target,
      listings: [
        _listing('Labubu Keychain Lot of 5', seller: 'a', price: 12),
        _listing('Pop Mart Labubu Macaron Figure', seller: 'b', price: 28),
        _listing('AUTHENTIC Labubu Macaron Plush', seller: 'c', price: 30),
      ],
    );
    expect(entries, isNotEmpty);
    expect(
      entries.first.representativeListing.collectible.name.toLowerCase(),
      isNot(contains('keychain')),
    );
  });

  test('mergeChaserEntries keeps highest score per cluster key', () {
    final low = ChasersHeatEntry(
      identityLabel: 'Labubu',
      clusterKey: 'cluster:labubu',
      representativeListing: _listing('Labubu A'),
      heatScore: 0.4,
      listingCount: 2,
      uniqueSellerCount: 2,
      brandId: 'pop_mart',
      ipId: 'the_monsters',
      ipLabel: 'THE MONSTERS',
    );
    final high = low.copyWithScore(0.8);
    final merged = mergeChaserEntries([low, high]);
    expect(merged.length, 1);
    expect(merged.first.heatScore, 0.8);
  });
}

extension on ChasersHeatEntry {
  ChasersHeatEntry copyWithScore(double heatScore) {
    return ChasersHeatEntry(
      identityLabel: identityLabel,
      clusterKey: clusterKey,
      representativeListing: representativeListing,
      heatScore: heatScore,
      listingCount: listingCount,
      uniqueSellerCount: uniqueSellerCount,
      brandId: brandId,
      ipId: ipId,
      ipLabel: ipLabel,
    );
  }
}
