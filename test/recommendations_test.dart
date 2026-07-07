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
    test('excludes custom-local and drop-import series', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'custom',
            catalogTemplateId: null,
            taxonomyIpId: 'dimoo',
          ),
          testShelfSeries(
            id: 'drop',
            catalogTemplateId: 'drop-legacy',
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

    test('low when one tracked catalog series on shelf', () {
      expect(
        computeConfidence(signals(tracked: 1)),
        RecommendationConfidence.low,
      );
      expect(isRecommendationReady(signals(tracked: 1)), isTrue);
    });

    test('low when tracked on shelf without owned figures', () {
      expect(
        computeConfidence(signals(tracked: 1, owned: 0)),
        RecommendationConfidence.low,
      );
      expect(isRecommendationReady(signals(tracked: 1, owned: 0)), isTrue);
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

    test('caps results at forYouResultLimit for a large catalog', () {
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
        for (var i = 0; i < 30; i++)
          catalog.CatalogSeries(
            id: 'series_$i',
            brandId: 'popmart',
            ipId: 'dimoo',
            displayName: 'Series $i',
            releaseDate: '2026-05-${(i % 28 + 1).toString().padLeft(2, '0')}',
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
          ips: const [
            CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
          ],
          series: manySeries,
          figures: const [],
        ),
        clock: DateTime(2026, 5, 21),
      );

      expect(items.length, RecommendationGatewayConfig.forYouResultLimit);
    });

    test('keeps top stable slots; exploration tied to profile and catalog', () {
      final manySeries = [
        for (var i = 0; i < 15; i++)
          catalog.CatalogSeries(
            id: 'labubu_$i',
            brandId: 'popmart',
            ipId: 'labubu',
            displayName: 'Labubu $i',
            releaseDate:
                '2026-05-${(15 - i).toString().padLeft(2, '0')}',
            isBlindBox: true,
            imageKey: 'labubu_$i',
          ),
      ];
      CatalogSeedBundle bundleFor(List<catalog.CatalogSeries> series) {
        return CatalogSeedBundle(
          brands: const [
            CatalogBrand(id: 'popmart', displayName: 'POP MART'),
          ],
          ips: const [
            CatalogIp(id: 'labubu', brandId: 'popmart', displayName: 'LABUBU'),
          ],
          series: series,
          figures: const [],
        );
      }

      PreferenceSignals signalsFor(String profileHash) {
        return PreferenceSignals(
          trackedCatalogSeriesIds: {'labubu_0'},
          ownedCatalogSeriesIds: {'labubu_0'},
          wishlistCatalogSeriesIds: const {},
          ownedIpIds: {'labubu'},
          wishlistIpIds: const {},
          trackedCatalogSeriesCount: 1,
          ownedCatalogSeriesCount: 1,
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
      expect(
        stable,
        [for (var i = 1; i <= 8; i++) 'labubu_$i'],
      );
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
          const catalog.CatalogSeries(
            id: 'labubu_new_drop',
            brandId: 'popmart',
            ipId: 'labubu',
            displayName: 'Labubu New',
            releaseDate: '2026-06-01',
            isBlindBox: true,
            imageKey: 'labubu_new_drop',
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
