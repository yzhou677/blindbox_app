import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/features/market/application/market_match_diagnostics.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_test/flutter_test.dart';

MarketListing _listing({MarketIdentityMatch? match, String provider = 'mock'}) {
  return MarketListing(
    id: 'x',
    providerId: provider,
    catalogMatch: match,
    collectible: Collectible(
      id: 'x',
      name: 'Figure',
      series: 'S',
      brand: 'B',
      releaseDate: DateTime.utc(2026),
      imageUrl: '',
    ),
    currentPriceUsd: 1,
    priceChangePercent: 0,
    listingCount: 1,
  );
}

void main() {
  test('summarize counts confidence and mercari rows', () {
    final d = MarketMatchDiagnostics.summarize([
      _listing(
        match: const MarketIdentityMatch(
          matchedBrandId: 'pop_mart',
          confidence: MarketMatchConfidence.low,
          score: 0.4,
        ),
      ),
      _listing(
        provider: 'mercari',
        match: MarketIdentityMatch.unresolved(
          unresolvedTokens: ['MYSTERY', 'TOKEN'],
        ),
      ),
    ]);

    expect(d.total, 2);
    expect(d.mercariCount, 1);
    expect(d.byConfidence[MarketMatchConfidence.low], 1);
    expect(d.byConfidence[MarketMatchConfidence.none], 1);
    expect(d.topUnresolvedTokens, isNotEmpty);
  });
}
