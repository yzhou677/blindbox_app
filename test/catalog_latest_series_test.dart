import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickLatestSeriesRecommendations sorts by releaseDate descending', () {
    final bundle = CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: [
        const catalog.CatalogSeries(
          id: 'old',
          brandId: 'pop_mart',
          ipId: 'the_monsters',
          displayName: 'Old',
          releaseDate: '2020-01-01',
          isBlindBox: true,
          imageKey: 'old',
        ),
        const catalog.CatalogSeries(
          id: 'new',
          brandId: 'pop_mart',
          ipId: 'the_monsters',
          displayName: 'New',
          releaseDate: '2026-01-01',
          isBlindBox: true,
          imageKey: 'new',
        ),
      ],
      figures: const [],
    );
    const snap = CollectionSnapshot(shelfSeries: [], figureStates: {});
    final picks = pickLatestSeriesRecommendations(bundle, snap, limit: 5);
    expect(picks.map((s) => s.id), ['new', 'old']);
  });

  test('pickLatestSeriesRecommendations includes series already on shelf', () {
    final bundle = CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: [
        const catalog.CatalogSeries(
          id: 'on_shelf',
          brandId: 'pop_mart',
          ipId: 'hirono',
          displayName: 'On shelf',
          releaseDate: '2026-02-01',
          isBlindBox: true,
          imageKey: 'on_shelf',
        ),
        const catalog.CatalogSeries(
          id: 'free',
          brandId: 'pop_mart',
          ipId: 'hirono',
          displayName: 'Free',
          releaseDate: '2025-01-01',
          isBlindBox: true,
          imageKey: 'free',
        ),
      ],
      figures: const [],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'user-1',
          name: 'User',
          brand: 'POP MART',
          ipName: 'Hirono',
          figures: const [],
          shelfAccent: Color(0xFFE4F2EA),
          catalogTemplateId: 'on_shelf',
        ),
      ],
      figureStates: const {},
    );
    final picks = pickLatestSeriesRecommendations(bundle, snap);
    expect(picks, hasLength(2));
    expect(picks.first.id, 'on_shelf');
    expect(picks.map((s) => s.id), contains('free'));
  });
}
