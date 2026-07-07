import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/collection/data/add_series_browse_feed.dart';
import 'package:blindbox_app/features/home/data/home_feed_picker.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _datedBundle() {
  return CatalogSeedBundle(
    brands: const [
      CatalogBrand(id: 'popmart', displayName: 'POP MART'),
    ],
    ips: const [
      CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
    ],
    series: [
      for (var i = 0; i < 6; i++)
        CatalogSeries(
          id: 'latest_$i',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Latest $i',
          releaseDate: '2026-05-${(20 - i).toString().padLeft(2, '0')}',
          isBlindBox: true,
          imageKey: 'latest_$i',
        ),
      for (var i = 0; i < 6; i++)
        CatalogSeries(
          id: 'trending_$i',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Trending $i',
          releaseDate: '2026-03-${(15 - i).toString().padLeft(2, '0')}',
          isBlindBox: true,
          imageKey: 'trending_$i',
        ),
    ],
    figures: const [],
  );
}

void main() {
  test('interleaveCatalogSeriesPools alternates latest and trending', () {
    final latest = [
      for (var i = 0; i < 3; i++)
        CatalogSeries(
          id: 'latest_$i',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Latest $i',
          releaseDate: '2026-05-01',
          isBlindBox: true,
          imageKey: 'latest_$i',
        ),
    ];
    final trending = [
      for (var i = 0; i < 3; i++)
        CatalogSeries(
          id: 'trending_$i',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Trending $i',
          releaseDate: '2026-03-01',
          isBlindBox: true,
          imageKey: 'trending_$i',
        ),
    ];

    final mixed = interleaveCatalogSeriesPools(
      latest: latest,
      trending: trending,
      targetCount: 6,
    );

    expect(mixed.map((s) => s.id), [
      'latest_0',
      'trending_0',
      'latest_1',
      'trending_1',
      'latest_2',
      'trending_2',
    ]);
  });

  test('interleaveCatalogSeriesPools skips duplicate series ids', () {
    final series = CatalogSeries(
      id: 'shared',
      brandId: 'popmart',
      ipId: 'dimoo',
      displayName: 'Shared',
      releaseDate: '2026-05-01',
      isBlindBox: true,
      imageKey: 'shared',
    );

    final mixed = interleaveCatalogSeriesPools(
      latest: [series],
      trending: [series],
      targetCount: 4,
    );

    expect(mixed, hasLength(1));
    expect(mixed.single.id, 'shared');
  });

  test('pickAddSeriesBrowseFeed uses home feed pools when dates match', () {
    resetTrendingSessionOrderForTest();
    final bundle = _datedBundle();
    final clock = DateTime(2026, 5, 21);

    final feed = pickAddSeriesBrowseFeed(bundle, clock: clock);

    expect(feed, isNotEmpty);
    expect(feed.map((s) => s.id).toSet().length, feed.length);
    expect(feed.first.id, startsWith('latest_'));
    if (feed.length >= 2) {
      expect(feed[1].id, startsWith('trending_'));
    }
  });
}
