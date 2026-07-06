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
      expect(signals.wishlistCatalogSeriesIds, {'labubu_a'});
      expect(signals.wishlistIpIds, {'labubu'});
      expect(signals.ownedCatalogSeriesIds, isEmpty);
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
      int owned = 0,
      int wishlist = 0,
    }) {
      return PreferenceSignals(
        ownedCatalogSeriesIds: {for (var i = 0; i < owned; i++) 'owned_$i'},
        wishlistCatalogSeriesIds: {
          for (var i = 0; i < wishlist; i++) 'wish_$i',
        },
        ownedIpIds: const {},
        wishlistIpIds: const {},
        ownedCatalogSeriesCount: owned,
        wishlistCatalogSeriesCount: wishlist,
        profileHash: 'hash',
      );
    }

    test('none when no owned or wishlist threshold met', () {
      expect(computeConfidence(signals()), RecommendationConfidence.none);
    });

    test('low when one owned series', () {
      expect(
        computeConfidence(signals(owned: 1)),
        RecommendationConfidence.low,
      );
      expect(isRecommendationReady(signals(owned: 1)), isTrue);
    });

    test('low when five wishlist series', () {
      expect(
        computeConfidence(signals(wishlist: 5)),
        RecommendationConfidence.low,
      );
    });

    test('medium at three owned series', () {
      expect(
        computeConfidence(signals(owned: 3)),
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

    test('ranks owned IP matches ahead of gap-fill and excludes owned series', () {
      final signals = PreferenceSignals(
        ownedCatalogSeriesIds: {'dimoo_owned'},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: {'dimoo'},
        wishlistIpIds: const {},
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

    test('caps results at forYouResultLimit for a large catalog', () {
      final signals = PreferenceSignals(
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: const {},
        wishlistIpIds: const {},
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
  });
}
