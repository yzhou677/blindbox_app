import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_rule_engine.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_confidence.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:blindbox_app/features/recommendations/presentation/for_you_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/collection_fixtures.dart';

ShelfSeries _ownedSeries({
  required String id,
  required String catalogTemplateId,
  required String taxonomyIpId,
}) {
  return testShelfSeries(
    id: id,
    catalogTemplateId: catalogTemplateId,
    taxonomyIpId: taxonomyIpId,
    figures: [
      ShelfFigure(
        id: '${id}_fig',
        seriesId: id,
        name: 'Owned Figure',
        rarity: 'Regular',
        isSecret: false,
        catalogFigureTemplateId: '${catalogTemplateId}_fig',
      ),
    ],
  );
}

ShelfSeries _wishlistSeries({
  required String id,
  required String catalogTemplateId,
  required String taxonomyIpId,
}) {
  return testShelfSeries(
    id: id,
    catalogTemplateId: catalogTemplateId,
    taxonomyIpId: taxonomyIpId,
    figures: [
      ShelfFigure(
        id: '${id}_fig',
        seriesId: id,
        name: 'Wishlist Figure',
        rarity: 'Regular',
        isSecret: false,
        catalogFigureTemplateId: '${catalogTemplateId}_fig',
      ),
    ],
  );
}

void main() {
  group('extractSignals', () {
    test('excludes custom-local and legacy mock drop imports', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'custom',
            catalogTemplateId: null,
            taxonomyIpId: 'dimoo',
          ),
          testShelfSeries(
            id: 'drop',
            catalogTemplateId: 'drop-drop-luna',
            taxonomyIpId: 'dimoo',
          ),
          _ownedSeries(
            id: 'owned',
            catalogTemplateId: 'dimoo_a',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: {
          'owned_fig': const TrackedFigure(
            figureId: 'owned_fig',
            state: FigureCollectionState.owned,
          ),
        },
      );

      final signals = extractSignals(snap);
      expect(signals.trackedCatalogSeriesIds, {'dimoo_a'});
      expect(signals.ownedCatalogSeriesIds, {'dimoo_a'});
      expect(signals.ownedIpIds, {'dimoo'});
      expect(signals.ownedCatalogSeriesCount, 1);
    });

    test('tracks catalog series saved from Home release drop import', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'drop_saved',
            catalogTemplateId: 'drop-the_monsters_macaron',
            taxonomyIpId: 'the_monsters',
          ),
        ],
        figureStates: const {},
      );

      final signals = extractSignals(snap);
      expect(signals.trackedCatalogSeriesIds, {'the_monsters_macaron'});
      expect(isRecommendationReady(signals), isFalse);
    });

    test('classifies purely wishlisted series without owned figures', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          _wishlistSeries(
            id: 'wish',
            catalogTemplateId: 'labubu_a',
            taxonomyIpId: 'labubu',
          ),
        ],
        figureStates: {
          'wish_fig': const TrackedFigure(
            figureId: 'wish_fig',
            state: FigureCollectionState.wishlist,
          ),
        },
      );

      final signals = extractSignals(snap);
      expect(signals.trackedCatalogSeriesIds, {'labubu_a'});
      expect(signals.wishlistCatalogSeriesIds, {'labubu_a'});
      expect(signals.wishlistIpIds, {'labubu'});
      expect(signals.ownedCatalogSeriesIds, isEmpty);
    });

    test('tracks catalog series on shelf without owned figures', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'shelf_only',
            catalogTemplateId: 'dimoo_shelf',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: const {},
      );

      final signals = extractSignals(snap);
      expect(signals.trackedCatalogSeriesIds, {'dimoo_shelf'});
      expect(signals.trackedCatalogSeriesCount, 1);
      expect(signals.ownedCatalogSeriesIds, isEmpty);
      expect(signals.ownedCatalogSeriesCount, 0);
      expect(isRecommendationReady(signals), isFalse);
    });

    test('readiness unlocks at three tracked catalog series', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          for (var i = 0; i < 3; i++)
            testShelfSeries(
              id: 'shelf_$i',
              catalogTemplateId: 'catalog_$i',
              taxonomyIpId: 'dimoo',
            ),
        ],
        figureStates: const {},
      );

      final signals = extractSignals(snap);
      expect(signals.trackedCatalogSeriesCount, 3);
      expect(isRecommendationReady(signals), isTrue);
    });

    test('profileHash is stable for identical signals', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          _ownedSeries(
            id: 'owned',
            catalogTemplateId: 'dimoo_a',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: {
          'owned_fig': const TrackedFigure(
            figureId: 'owned_fig',
            state: FigureCollectionState.owned,
          ),
        },
      );

      final a = extractSignals(snap);
      final b = extractSignals(snap);
      expect(a.profileHash, b.profileHash);
      expect(a.profileHash, isNotEmpty);
    });

    test('profileHash changes only when tracked catalog series change', () {
      final trackedOnly = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'shelf_a',
            catalogTemplateId: 'dimoo_a',
            taxonomyIpId: 'dimoo',
          ),
          testShelfSeries(
            id: 'shelf_b',
            catalogTemplateId: 'dimoo_b',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: const {},
      );
      final withOwned = CollectionSnapshot(
        shelfSeries: trackedOnly.shelfSeries,
        figureStates: const {
          'shelf_a_fig': TrackedFigure(
            figureId: 'shelf_a_fig',
            state: FigureCollectionState.owned,
          ),
        },
      );
      final withWishlist = CollectionSnapshot(
        shelfSeries: [
          _wishlistSeries(
            id: 'shelf_a',
            catalogTemplateId: 'dimoo_a',
            taxonomyIpId: 'dimoo',
          ),
          testShelfSeries(
            id: 'shelf_b',
            catalogTemplateId: 'dimoo_b',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: const {
          'shelf_a_fig': TrackedFigure(
            figureId: 'shelf_a_fig',
            state: FigureCollectionState.wishlist,
          ),
        },
      );
      final trackedAdded = CollectionSnapshot(
        shelfSeries: [
          ...trackedOnly.shelfSeries,
          testShelfSeries(
            id: 'shelf_c',
            catalogTemplateId: 'dimoo_c',
            taxonomyIpId: 'dimoo',
          ),
        ],
        figureStates: const {},
      );

      final base = extractSignals(trackedOnly);
      expect(extractSignals(withOwned).profileHash, base.profileHash);
      expect(extractSignals(withWishlist).profileHash, base.profileHash);
      expect(extractSignals(trackedAdded).profileHash, isNot(base.profileHash));
    });
  });

  group('computeConfidence', () {
    PreferenceSignals signals({
      int tracked = 0,
      int owned = 0,
      int wishlist = 0,
    }) {
      return PreferenceSignals(
        trackedCatalogSeriesIds: {
          for (var i = 0; i < tracked; i++) 'tracked_$i',
        },
        ownedCatalogSeriesIds: {for (var i = 0; i < owned; i++) 'owned_$i'},
        wishlistCatalogSeriesIds: {
          for (var i = 0; i < wishlist; i++) 'wish_$i',
        },
        ownedIpIds: const {},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: tracked,
        ownedCatalogSeriesCount: owned,
        wishlistCatalogSeriesCount: wishlist,
        profileHash: 'hash',
      );
    }

    test('none when no catalog series tracked on shelf', () {
      expect(computeConfidence(signals()), RecommendationConfidence.none);
      expect(isRecommendationReady(signals()), isFalse);
    });

    test('low when three tracked catalog series on shelf', () {
      expect(
        computeConfidence(signals(tracked: 3)),
        RecommendationConfidence.low,
      );
      expect(isRecommendationReady(signals(tracked: 3)), isTrue);
    });

    test('none when fewer than three tracked catalog series', () {
      expect(
        computeConfidence(signals(tracked: 2)),
        RecommendationConfidence.none,
      );
      expect(isRecommendationReady(signals(tracked: 2)), isFalse);
    });

    test('low when tracked on shelf without owned figures', () {
      expect(
        computeConfidence(signals(tracked: 3, owned: 0)),
        RecommendationConfidence.low,
      );
      expect(isRecommendationReady(signals(tracked: 3, owned: 0)), isTrue);
    });

    test('medium at three owned series', () {
      expect(
        computeConfidence(signals(tracked: 3, owned: 3)),
        RecommendationConfidence.medium,
      );
    });
  });

  group('computeLocalRecommendations', () {
    CatalogSeedBundle bundle() {
      return CatalogSeedBundle(
        brands: const [
          CatalogBrand(id: 'popmart', displayName: 'POP MART'),
        ],
        ips: const [
          CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
          CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
        ],
        series: [
          catalog.CatalogSeries(
            id: 'dimoo_owned',
            brandId: 'popmart',
            ipId: 'dimoo',
            displayName: 'Dimoo Owned',
            releaseDate: '2026-01-01',
            isBlindBox: true,
            imageKey: 'dimoo_owned',
          ),
          catalog.CatalogSeries(
            id: 'dimoo_new',
            brandId: 'popmart',
            ipId: 'dimoo',
            displayName: 'Dimoo New',
            releaseDate: '2026-05-01',
            isBlindBox: true,
            imageKey: 'dimoo_new',
          ),
          catalog.CatalogSeries(
            id: 'labubu_gap',
            brandId: 'popmart',
            ipId: 'labubu',
            displayName: 'Labubu Gap',
            releaseDate: '2026-04-01',
            isBlindBox: true,
            imageKey: 'labubu_gap',
          ),
        ],
        figures: const [],
      );
    }

    test('ranks owned IP matches ahead of gap-fill and excludes tracked series', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: {'dimoo_owned'},
        ownedCatalogSeriesIds: {'dimoo_owned'},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: {'dimoo'},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 1,
        ownedCatalogSeriesCount: 1,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );

      final items = computeLocalRecommendations(
        signals: signals,
        bundle: bundle(),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.map((item) => item.seriesId), contains('dimoo_new'));
      expect(items.map((item) => item.seriesId), isNot(contains('dimoo_owned')));
      expect(
        items.firstWhere((item) => item.seriesId == 'dimoo_new').reasonType,
        RecommendationReasonType.recentRelease,
      );
    });

    test('forYouReason maps reason codes to copy', () {
      expect(
        forYouReason(RecommendationReasonType.ownedIp, 'DIMOO'),
        'Because you collect DIMOO',
      );
      expect(
        forYouReason(RecommendationReasonType.wishlistIp, 'LABUBU'),
        'Similar to your LABUBU wishlist',
      );
      expect(forYouReason(RecommendationReasonType.newInCatalog, null), 'New in catalog');
    });

    test('does not score wishlist IP affinity', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: {'labubu_owned'},
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: {'labubu_owned'},
        ownedIpIds: const {},
        wishlistIpIds: {'labubu'},
        trackedCatalogSeriesCount: 1,
        ownedCatalogSeriesCount: 0,
        wishlistCatalogSeriesCount: 1,
        profileHash: 'hash',
      );

      final items = computeLocalRecommendations(
        signals: signals,
        bundle: CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: const [
            CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
          ],
          series: const [
            catalog.CatalogSeries(
              id: 'labubu_owned',
              brandId: 'popmart',
              ipId: 'labubu',
              displayName: 'Labubu Owned',
              releaseDate: '2026-01-01',
              isBlindBox: true,
              imageKey: 'labubu_owned',
            ),
            catalog.CatalogSeries(
              id: 'labubu_new',
              brandId: 'popmart',
              ipId: 'labubu',
              displayName: 'Labubu New',
              releaseDate: '2026-05-01',
              isBlindBox: true,
              imageKey: 'labubu_new',
            ),
          ],
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      expect(
        items.any(
          (item) => item.reasonType == RecommendationReasonType.wishlistIp,
        ),
        isFalse,
      );
    });

    test('never recommends shelf-tracked catalog series without owned figures', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: {'dimoo_owned'},
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: const {},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 1,
        ownedCatalogSeriesCount: 0,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );

      final items = computeLocalRecommendations(
        signals: signals,
        bundle: bundle(),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.map((item) => item.seriesId), isNot(contains('dimoo_owned')));
      expect(items.map((item) => item.seriesId), contains('dimoo_new'));
    });

    test('gap fills to minimum when scored picks are below 5', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: {'dimoo_owned'},
        ownedCatalogSeriesIds: {'dimoo_owned'},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: {'dimoo'},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 1,
        ownedCatalogSeriesCount: 1,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );
      final items = computeLocalRecommendations(
        signals: signals,
        bundle: CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: const [
            CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
            CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
            CatalogIp(id: 'crybaby', brandId: 'popmart', displayName: 'CRYBABY'),
          ],
          series: const [
            catalog.CatalogSeries(
              id: 'dimoo_owned',
              brandId: 'popmart',
              ipId: 'dimoo',
              displayName: 'Dimoo Owned',
              releaseDate: '2026-01-01',
              isBlindBox: true,
              imageKey: 'dimoo_owned',
            ),
            catalog.CatalogSeries(
              id: 'dimoo_a',
              brandId: 'popmart',
              ipId: 'dimoo',
              displayName: 'Dimoo A',
              releaseDate: '2026-05-03',
              isBlindBox: true,
              imageKey: 'dimoo_a',
            ),
            catalog.CatalogSeries(
              id: 'dimoo_b',
              brandId: 'popmart',
              ipId: 'dimoo',
              displayName: 'Dimoo B',
              releaseDate: '2026-05-02',
              isBlindBox: true,
              imageKey: 'dimoo_b',
            ),
            catalog.CatalogSeries(
              id: 'dimoo_c',
              brandId: 'popmart',
              ipId: 'dimoo',
              displayName: 'Dimoo C',
              releaseDate: '2026-05-01',
              isBlindBox: true,
              imageKey: 'dimoo_c',
            ),
            catalog.CatalogSeries(
              id: 'labubu_gap_1',
              brandId: 'popmart',
              ipId: 'labubu',
              displayName: 'Labubu Gap 1',
              releaseDate: '2026-06-01',
              isBlindBox: true,
              imageKey: 'labubu_gap_1',
            ),
            catalog.CatalogSeries(
              id: 'labubu_gap_2',
              brandId: 'popmart',
              ipId: 'labubu',
              displayName: 'Labubu Gap 2',
              releaseDate: '2026-06-02',
              isBlindBox: true,
              imageKey: 'labubu_gap_2',
            ),
            catalog.CatalogSeries(
              id: 'crybaby_gap',
              brandId: 'popmart',
              ipId: 'crybaby',
              displayName: 'Crybaby Gap',
              releaseDate: '2026-06-03',
              isBlindBox: true,
              imageKey: 'crybaby_gap',
            ),
          ],
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.length, RecommendationGatewayConfig.forYouMinimumResultCount);
      expect(
        items.where((item) => item.reasonType == RecommendationReasonType.newInCatalog).length,
        3,
      );
    });

    test('limits scored picks to two per IP while preserving score order', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: const {},
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: {'labubu'},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 0,
        ownedCatalogSeriesCount: 0,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );
      final items = computeLocalRecommendations(
        signals: signals,
        bundle: CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: const [
            CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
            CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
            CatalogIp(id: 'crybaby', brandId: 'popmart', displayName: 'CRYBABY'),
            CatalogIp(id: 'nommi', brandId: 'popmart', displayName: 'NOMMI'),
            CatalogIp(id: 'molly', brandId: 'popmart', displayName: 'MOLLY'),
          ],
          series: [
            for (var i = 1; i <= 6; i++)
              catalog.CatalogSeries(
                id: 'labubu_$i',
                brandId: 'popmart',
                ipId: 'labubu',
                displayName: 'Labubu $i',
                releaseDate: '2026-05-${i.toString().padLeft(2, '0')}',
                isBlindBox: true,
                imageKey: 'labubu_$i',
              ),
            catalog.CatalogSeries(
              id: 'dimoo_1',
              brandId: 'popmart',
              ipId: 'dimoo',
              displayName: 'Dimoo 1',
              releaseDate: '2026-04-01',
              isBlindBox: true,
              imageKey: 'dimoo_1',
            ),
            catalog.CatalogSeries(
              id: 'crybaby_1',
              brandId: 'popmart',
              ipId: 'crybaby',
              displayName: 'Crybaby 1',
              releaseDate: '2026-04-02',
              isBlindBox: true,
              imageKey: 'crybaby_1',
            ),
            catalog.CatalogSeries(
              id: 'nommi_1',
              brandId: 'popmart',
              ipId: 'nommi',
              displayName: 'Nommi 1',
              releaseDate: '2026-04-03',
              isBlindBox: true,
              imageKey: 'nommi_1',
            ),
            catalog.CatalogSeries(
              id: 'molly_1',
              brandId: 'popmart',
              ipId: 'molly',
              displayName: 'Molly 1',
              releaseDate: '2026-04-04',
              isBlindBox: true,
              imageKey: 'molly_1',
            ),
          ],
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      final ipCounts = <String, int>{};
      for (final item in items) {
        final ipId = switch (item.seriesId) {
          final id when id.startsWith('labubu_') => 'labubu',
          final id when id.startsWith('dimoo_') => 'dimoo',
          final id when id.startsWith('crybaby_') => 'crybaby',
          final id when id.startsWith('nommi_') => 'nommi',
          final id when id.startsWith('molly_') => 'molly',
          _ => item.seriesId,
        };
        ipCounts[ipId] = (ipCounts[ipId] ?? 0) + 1;
      }
      for (final count in ipCounts.values) {
        expect(count, lessThanOrEqualTo(2));
      }
      expect(ipCounts['labubu'], 2);
      expect(items.map((item) => item.seriesId), containsAll(['labubu_6', 'labubu_5']));
      expect(items.map((item) => item.seriesId), isNot(contains('labubu_4')));
    });

    test('skips gap fill when scored picks reach minimum', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: {'labubu_0', 'dimoo_0', 'crybaby_0'},
        ownedCatalogSeriesIds: {'labubu_0', 'dimoo_0', 'crybaby_0'},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: {'labubu', 'dimoo', 'crybaby'},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 3,
        ownedCatalogSeriesCount: 3,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );
      final manySeries = [
        for (final ip in ['labubu', 'dimoo', 'crybaby'])
          for (var i = 0; i < 3; i++)
            catalog.CatalogSeries(
              id: '${ip}_$i',
              brandId: 'popmart',
              ipId: ip,
              displayName: '$ip $i',
              releaseDate: '2026-05-${(9 - i).toString().padLeft(2, '0')}',
              isBlindBox: true,
              imageKey: '${ip}_$i',
            ),
      ];

      final items = computeLocalRecommendations(
        signals: signals,
        bundle: CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: const [
            CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
            CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
            CatalogIp(id: 'crybaby', brandId: 'popmart', displayName: 'CRYBABY'),
          ],
          series: manySeries,
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.length, 6);
      expect(
        items.any((item) => item.reasonType == RecommendationReasonType.newInCatalog),
        isFalse,
      );
    });

    test('caps scored results at forYouResultLimit for a large catalog', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: const {},
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: {for (var i = 0; i < 10; i++) 'ip_$i'},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 0,
        ownedCatalogSeriesCount: 0,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );
      final manySeries = [
        for (var ip = 0; ip < 10; ip++)
          for (var i = 0; i < 3; i++)
            catalog.CatalogSeries(
              id: 'series_${ip}_$i',
              brandId: 'popmart',
              ipId: 'ip_$ip',
              displayName: 'Series $ip-$i',
              releaseDate: '2026-05-${(ip * 3 + i + 1).toString().padLeft(2, '0')}',
              isBlindBox: true,
              imageKey: 'series_${ip}_$i',
            ),
      ];

      final items = computeLocalRecommendations(
        signals: signals,
        bundle: CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: [
            for (var i = 0; i < 10; i++)
              CatalogIp(id: 'ip_$i', brandId: 'popmart', displayName: 'IP $i'),
          ],
          series: manySeries,
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.length, RecommendationGatewayConfig.forYouResultLimit);
      final ipCounts = <String, int>{};
      for (final item in items) {
        final parts = item.seriesId.split('_');
        final ipId = 'ip_${parts[1]}';
        ipCounts[ipId] = (ipCounts[ipId] ?? 0) + 1;
      }
      for (final count in ipCounts.values) {
        expect(count, lessThanOrEqualTo(2));
      }
    });

    test('gap fills only to minimum when no scored picks exist', () {
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: const {},
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: const {},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 0,
        ownedCatalogSeriesCount: 0,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );
      final manySeries = [
        for (var i = 0; i < 5; i++)
          catalog.CatalogSeries(
            id: 'series_$i',
            brandId: 'popmart',
            ipId: 'ip_$i',
            displayName: 'Series $i',
            releaseDate: '2026-05-${(5 - i).toString().padLeft(2, '0')}',
            isBlindBox: true,
            imageKey: 'series_$i',
          ),
      ];

      final items = computeLocalRecommendations(
        signals: signals,
        bundle: CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: [
            for (var i = 0; i < 5; i++)
              CatalogIp(id: 'ip_$i', brandId: 'popmart', displayName: 'IP $i'),
          ],
          series: manySeries,
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.length, RecommendationGatewayConfig.forYouMinimumResultCount);
      expect(
        items.every((item) => item.reasonType == RecommendationReasonType.newInCatalog),
        isTrue,
      );
    });

    test('gap fill randomizes within recent pool and stays stable per profile', () {
      CatalogSeedBundle bundleForPool() {
        return CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: [
            for (var i = 0; i < 25; i++)
              CatalogIp(id: 'ip_$i', brandId: 'popmart', displayName: 'IP $i'),
          ],
          series: [
            for (var i = 0; i < 25; i++)
              catalog.CatalogSeries(
                id: 'series_$i',
                brandId: 'popmart',
                ipId: 'ip_$i',
                displayName: 'Series $i',
                releaseDate: '2026-05-${(25 - i).toString().padLeft(2, '0')}',
                isBlindBox: true,
                imageKey: 'series_$i',
              ),
          ],
          figures: const [],
        );
      }

      PreferenceSignals signalsFor(String profileHash) {
        return PreferenceSignals(
          trackedCatalogSeriesIds: const {},
          ownedCatalogSeriesIds: const {},
          wishlistCatalogSeriesIds: const {},
          ownedIpIds: const {},
          wishlistIpIds: const {},
          trackedCatalogSeriesCount: 0,
          ownedCatalogSeriesCount: 0,
          wishlistCatalogSeriesCount: 0,
          profileHash: profileHash,
        );
      }

      final bundle = bundleForPool();
      final run = (String profileHash) => computeLocalRecommendations(
            signals: signalsFor(profileHash),
            bundle: bundle,
            clock: DateTime(2026, 5, 21),
          );

      final stableRun = run('profile-gap-fill');
      final repeatRun = run('profile-gap-fill');
      final alternateRun = run('profile-gap-fill-v2');

      expect(stableRun.map((item) => item.seriesId).toList(),
          repeatRun.map((item) => item.seriesId).toList());
      expect(stableRun, hasLength(5));
      for (final item in stableRun) {
        final index = int.parse(item.seriesId.split('_').last);
        expect(index, lessThan(20));
      }
      expect(
        stableRun.map((item) => item.seriesId).toList(),
        isNot(equals(
          [for (var i = 0; i < 5; i++) 'series_$i'],
        )),
      );
      expect(
        alternateRun.map((item) => item.seriesId).toList(),
        isNot(equals(stableRun.map((item) => item.seriesId).toList())),
      );
    });

    test('keeps top stable slots; exploration tied to profile and catalog', () {
      final manySeries = [
        for (var ip = 0; ip < 10; ip++)
          for (var i = 0; i < 2; i++)
            catalog.CatalogSeries(
              id: 'ip${ip}_$i',
              brandId: 'popmart',
              ipId: 'ip_$ip',
              displayName: 'IP $ip series $i',
              releaseDate:
                  '2026-05-${(20 - ip * 2 - i).toString().padLeft(2, '0')}',
              isBlindBox: true,
              imageKey: 'ip${ip}_$i',
            ),
      ];
      CatalogSeedBundle bundleFor(List<catalog.CatalogSeries> series) {
        return CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: [
            for (var i = 0; i < 10; i++)
              CatalogIp(id: 'ip_$i', brandId: 'popmart', displayName: 'IP $i'),
          ],
          series: series,
          figures: const [],
        );
      }

      PreferenceSignals signalsFor(String profileHash) {
        return PreferenceSignals(
          trackedCatalogSeriesIds: const {},
          ownedCatalogSeriesIds: const {},
          wishlistCatalogSeriesIds: const {},
          ownedIpIds: {for (var i = 0; i < 10; i++) 'ip_$i'},
          wishlistIpIds: const {},
          trackedCatalogSeriesCount: 0,
          ownedCatalogSeriesCount: 0,
          wishlistCatalogSeriesCount: 0,
          profileHash: profileHash,
        );
      }

      final bundle = bundleFor(manySeries);
      final signals = signalsFor('profile-hash');
      final run = ({
        required PreferenceSignals signals,
        required CatalogSeedBundle bundle,
        DateTime? clock,
      }) =>
          computeLocalRecommendations(
            signals: signals,
            bundle: bundle,
            clock: clock ?? DateTime.utc(2026, 5, 21),
          );

      final baseline = run(signals: signals, bundle: bundle);
      final stable = baseline.take(8).map((item) => item.seriesId).toList();
      final explore = baseline.skip(8).map((item) => item.seriesId).toList();

      expect(baseline, hasLength(10));
      expect(stable, hasLength(8));
      expect(explore, hasLength(2));
      expect(explore.toSet(), isNot(containsAll(stable)));

      // Same profile + same catalog → stable exploration (not calendar-driven).
      expect(
        run(signals: signals, bundle: bundle, clock: DateTime.utc(2026, 6, 2))
            .skip(8)
            .map((item) => item.seriesId)
            .toList(),
        explore,
      );

      // Profile change → exploration may change.
      final profileChanged = run(
        signals: signalsFor('profile-hash-v2'),
        bundle: bundle,
      );
      expect(
        profileChanged.skip(8).map((item) => item.seriesId).toList(),
        isNot(equals(explore)),
      );

      // Catalog change → exploration may change.
      final catalogChanged = run(
        signals: signals,
        bundle: bundleFor([
          ...manySeries,
          catalog.CatalogSeries(
            id: 'ip_new_drop',
            brandId: 'popmart',
            ipId: 'ip_9',
            displayName: 'IP 9 new',
            releaseDate: '2026-06-01',
            isBlindBox: true,
            imageKey: 'ip_new_drop',
          ),
        ]),
      );
      expect(
        catalogChanged.skip(8).map((item) => item.seriesId).toList(),
        isNot(equals(explore)),
      );
    });
  });
}
