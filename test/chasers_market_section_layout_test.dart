import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_card_tokens.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/widgets/chasers_market_section.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _listing(String id) {
  return MarketListing(
    id: id,
    currentPriceUsd: 29.99,
    priceChangePercent: 0,
    listingCount: 1,
    collectible: Collectible(
      id: id,
      name: 'Figure $id',
      series: 'Series $id with a longer title for two lines',
      brand: 'POP MART',
      releaseDate: DateTime(2026, 1, 1),
      imageUrl: '',
    ),
  );
}

void main() {
  testWidgets('Chasers cards share equal rail tile size', (tester) async {
    final entries = [
      ChasersHeatEntry(
        clusterKey: 'a',
        identityLabel: 'Short',
        ipLabel: 'DIMOO',
        brandId: 'pop_mart',
        ipId: 'dimoo',
        representativeListing: _listing('a'),
        heatScore: 1,
        listingCount: 1,
        uniqueSellerCount: 1,
      ),
      ChasersHeatEntry(
        clusterKey: 'b',
        identityLabel:
            'An Extremely Long Chaser Identity That Should Clamp Across Two Lines',
        ipLabel: 'THE MONSTERS',
        brandId: 'pop_mart',
        ipId: 'monsters',
        representativeListing: _listing('b'),
        heatScore: 2,
        listingCount: 2,
        uniqueSellerCount: 1,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ChasersMarketSection(entries: entries)),
      ),
    );
    await tester.pump();

    final cards = find.byWidgetPredicate(
      (w) =>
          w is SizedBox &&
          w.width == AppCardTokens.browseRailWidth &&
          w.height == FeedRhythm.marketChasersRailHeight,
    );
    expect(cards, findsNWidgets(2));

    final a = tester.getSize(cards.at(0));
    final b = tester.getSize(cards.at(1));
    expect(a, b);
    expect(a.width, AppCardTokens.browseRailWidth);
    expect(a.height, FeedRhythm.marketChasersRailHeight);
  });
}
