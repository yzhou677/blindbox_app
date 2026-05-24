import 'package:blindbox_app/features/market/domain/market_title_clusterer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketTitleClusterer', () {
    const clusterer = MarketTitleClusterer(hintTokens: ['labubu', 'macaron']);

    test('clusters similar Labubu Macaron titles', () {
      final clusters = clusterer.cluster([
        const MarketTitleClusterInput(
          title: 'POP MART Labubu Exciting Macaron Series Blind Box Confirmed',
          sellerUsername: 'seller_a',
          priceUsd: 24,
        ),
        const MarketTitleClusterInput(
          title: 'Pop Mart LABUBU Macaron Vinyl Figure Sealed',
          sellerUsername: 'seller_b',
          priceUsd: 28,
        ),
        const MarketTitleClusterInput(
          title: 'POP MART Dimoo World Series Figure',
          sellerUsername: 'seller_c',
          priceUsd: 18,
        ),
      ]);

      expect(clusters, isNotEmpty);
      final labubu = clusters.firstWhere((c) => c.label.toLowerCase().contains('labubu'));
      expect(labubu.listingCount, 2);
      expect(labubu.uniqueSellerCount, 2);
    });

    test('flags accessory-heavy clusters', () {
      final clusters = clusterer.cluster([
        const MarketTitleClusterInput(title: 'Labubu Macaron Keychain Charm Lot'),
        const MarketTitleClusterInput(title: 'Labubu Macaron Pendant Lanyard'),
      ]);
      expect(clusters.single.likelyAccessoryHeavy, isTrue);
    });

    test('ignores singleton listings below minClusterSize', () {
      final clusters = clusterer.cluster([
        const MarketTitleClusterInput(title: 'Unique One Off Listing Title Here'),
      ]);
      expect(clusters, isEmpty);
    });
  });
}
