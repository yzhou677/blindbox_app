import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter_test/flutter_test.dart';

const _blindBoxSeriesId = 'series_bie';
const _standaloneSeriesId = 'mega_crybaby_400_crying_in_pink';

MarketSnapshot _snapshot({
  SnapshotLevel level = SnapshotLevel.figure,
  String? figureId = 'fig_luck',
  String seriesId = _blindBoxSeriesId,
  int recentSalesCount = 18,
  double? priceRangeMinUsd = 38,
  double? priceRangeMaxUsd = 48,
  SnapshotConfidence confidence = SnapshotConfidence.high,
  MarketTrend trend = MarketTrend.rising,
  DateTime? computedAt,
}) {
  return MarketSnapshot(
    id: figureId ?? seriesId,
    level: level,
    figureId: level == SnapshotLevel.figure ? figureId : null,
    seriesId: seriesId,
    estimatedValueUsd: 42,
    trend: trend,
    confidence: confidence,
    recentSalesCount: recentSalesCount,
    priceRangeMinUsd: priceRangeMinUsd,
    priceRangeMaxUsd: priceRangeMaxUsd,
    computedAt: computedAt ?? DateTime.utc(2026, 6, 15),
  );
}

CatalogSeries _blindBoxSeries() {
  return CatalogSeries(
    id: _blindBoxSeriesId,
    brandId: 'pop_mart',
    ipId: 'crybaby',
    displayName: 'Blind Box Series',
    releaseDate: '2025-01-01',
    isBlindBox: true,
    imageKey: _blindBoxSeriesId,
  );
}

CatalogSeries _standaloneSeries() {
  return CatalogSeries(
    id: _standaloneSeriesId,
    brandId: 'pop_mart',
    ipId: 'crybaby',
    displayName: 'MEGA CRYBABY 400% Crying in Pink',
    releaseDate: '2025-01-01',
    isBlindBox: false,
    imageKey: _standaloneSeriesId,
  );
}

void main() {
  tearDown(CatalogBundleCache.resetForTest);
  group('formatMarketSnapshotValue', () {
    test('formats rounded USD without tilde', () {
      expect(formatMarketSnapshotValue(42), '\$42');
    });
  });

  group('formatMarketSnapshotDiscoverDisclosureLabel', () {
    test('collapsed uses right-pointing chevron', () {
      expect(
        formatMarketSnapshotDiscoverDisclosureLabel(expanded: false),
        '▶ Market Information',
      );
    });

    test('expanded uses down-pointing chevron', () {
      expect(
        formatMarketSnapshotDiscoverDisclosureLabel(expanded: true),
        '▼ Market Information',
      );
    });
  });

  group('formatMarketSnapshotDiscoverSummaryLine', () {
    test('figure snapshot includes sales count', () {
      expect(
        formatMarketSnapshotDiscoverSummaryLine(_snapshot()),
        'Market Value · \$42 · 18 sales',
      );
    });

    test('series fallback uses series avg label and sales', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_blindBoxSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketSnapshotDiscoverSummaryLine(
          _snapshot(
            level: SnapshotLevel.series,
            figureId: null,
            recentSalesCount: 4,
            confidence: SnapshotConfidence.low,
          ),
        ),
        'Series Avg. · \$42 · 4 sales',
      );
    });

    test('non-blind-box series fallback uses market estimate label', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_standaloneSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketSnapshotDiscoverSummaryLine(
          _snapshot(
            level: SnapshotLevel.series,
            figureId: null,
            seriesId: _standaloneSeriesId,
            recentSalesCount: 6,
            confidence: SnapshotConfidence.low,
          ),
        ),
        'Market Estimate · \$42 · 6 sales',
      );
    });

    test('omits sales segment when count is zero', () {
      expect(
        formatMarketSnapshotDiscoverSummaryLine(
          _snapshot(recentSalesCount: 0),
        ),
        'Market Value · \$42',
      );
    });
  });

  group('formatMarketSnapshotDiscoverSalesSegment', () {
    test('returns plain sales count without asterisk', () {
      expect(
        formatMarketSnapshotDiscoverSalesSegment(
          _snapshot(
            confidence: SnapshotConfidence.low,
            recentSalesCount: 4,
          ),
        ),
        '4 sales',
      );
    });
  });

  group('formatMarketSnapshotDiscoverRecentSalesLine', () {
    test('returns recent sales wording', () {
      expect(
        formatMarketSnapshotDiscoverRecentSalesLine(_snapshot()),
        '18 recent sales',
      );
    });
  });

  group('formatMarketSnapshotDiscoverPriceRangeValue', () {
    test('returns en-dash range without suffix', () {
      expect(
        formatMarketSnapshotDiscoverPriceRangeValue(_snapshot()),
        '\$38–\$48',
      );
    });
  });

  group('formatMarketSnapshotSalesLine', () {
    test('returns sales count for positive sample', () {
      expect(formatMarketSnapshotSalesLine(_snapshot()), '18 sales');
    });

    test('does not append asterisk for low confidence', () {
      expect(
        formatMarketSnapshotSalesLine(
          _snapshot(confidence: SnapshotConfidence.low, recentSalesCount: 4),
        ),
        '4 sales',
      );
    });

    test('returns null when count is zero', () {
      expect(
        formatMarketSnapshotSalesLine(_snapshot(recentSalesCount: 0)),
        isNull,
      );
    });
  });

  group('formatMarketSnapshotPriceRangeLine', () {
    test('returns en-dash range line', () {
      expect(
        formatMarketSnapshotPriceRangeLine(_snapshot()),
        '\$38–\$48 range',
      );
    });

    test('returns null when min is missing', () {
      expect(
        formatMarketSnapshotPriceRangeLine(
          _snapshot(priceRangeMinUsd: null),
        ),
        isNull,
      );
    });

    test('returns null when max is missing', () {
      expect(
        formatMarketSnapshotPriceRangeLine(
          _snapshot(priceRangeMaxUsd: null),
        ),
        isNull,
      );
    });
  });

  group('formatMarketSnapshotUpdatedLine', () {
    test('uses relative time for recent dates', () {
      final computedAt = DateTime.utc(2026, 6, 12);
      final clock = DateTime.utc(2026, 6, 15);
      expect(
        formatMarketSnapshotUpdatedLine(computedAt, clock: clock),
        'Updated 3d ago',
      );
    });

    test('uses month-day for older dates', () {
      final computedAt = DateTime.utc(2026, 6, 15);
      final clock = DateTime.utc(2026, 9, 15);
      expect(
        formatMarketSnapshotUpdatedLine(computedAt, clock: clock),
        'Updated Jun 15',
      );
    });
  });

  group('formatMarketSnapshotInsightsActivitySalesLine', () {
    test('returns recent sales wording', () {
      expect(
        formatMarketSnapshotInsightsActivitySalesLine(_snapshot()),
        '18 recent sales',
      );
    });
  });

  group('formatMarketSnapshotInsightsRangeLine', () {
    test('prefixes range label', () {
      expect(
        formatMarketSnapshotInsightsRangeLine(_snapshot()),
        'Range \$38–\$48',
      );
    });
  });

  group('formatMarketSnapshotInsightsUpdatedMetadataLine', () {
    test('includes updated prefix', () {
      final computedAt = DateTime.utc(2026, 6, 12);
      final clock = DateTime.utc(2026, 6, 15);
      expect(
        formatMarketSnapshotInsightsUpdatedMetadataLine(computedAt, clock: clock),
        'Updated 3d ago',
      );
    });
  });

  group('formatMarketSnapshotInsightsRecentSalesCount', () {
    test('returns plain count', () {
      expect(
        formatMarketSnapshotInsightsRecentSalesCount(_snapshot()),
        '18',
      );
    });
  });

  group('formatMarketSnapshotInsightsUpdatedValue', () {
    test('returns relative time without updated prefix', () {
      final computedAt = DateTime.utc(2026, 6, 12);
      final clock = DateTime.utc(2026, 6, 15);
      expect(
        formatMarketSnapshotInsightsUpdatedValue(computedAt, clock: clock),
        '3d ago',
      );
    });
  });

  group('formatMarketSnapshotTrendLabel', () {
    test('maps rising to Trending', () {
      expect(formatMarketSnapshotTrendLabel(MarketTrend.rising), 'Trending');
    });

    test('returns null for unknown', () {
      expect(formatMarketSnapshotTrendLabel(MarketTrend.unknown), isNull);
    });
  });

  group('formatMarketListingPriceDeltaLine', () {
    test('figure snapshot above market includes rounded percent', () {
      expect(
        formatMarketListingPriceDeltaLine(48, 42, isSeriesEstimate: false),
        '▲ 14% above market',
      );
    });

    test('figure snapshot below market uses checkmark copy', () {
      expect(
        formatMarketListingPriceDeltaLine(35, 42, isSeriesEstimate: false),
        '✓ Below market',
      );
    });

    test('figure snapshot within five percent is at market', () {
      expect(
        formatMarketListingPriceDeltaLine(42, 42, isSeriesEstimate: false),
        '≈ At market',
      );
      expect(
        formatMarketListingPriceDeltaLine(43, 42, isSeriesEstimate: false),
        '≈ At market',
      );
    });

    test('series estimate above uses series avg wording', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_blindBoxSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketListingPriceDeltaLine(
          48,
          42,
          isSeriesEstimate: true,
          seriesId: _blindBoxSeriesId,
        ),
        '▲ 14% above series avg.',
      );
    });

    test('series estimate below omits checkmark', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_blindBoxSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketListingPriceDeltaLine(
          35,
          42,
          isSeriesEstimate: true,
          seriesId: _blindBoxSeriesId,
        ),
        'Below series avg.',
      );
    });

    test('series estimate within five percent is near series avg', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_blindBoxSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketListingPriceDeltaLine(
          42,
          42,
          isSeriesEstimate: true,
          seriesId: _blindBoxSeriesId,
        ),
        '≈ Near series avg.',
      );
    });

    test('non-blind-box series estimate above uses market estimate wording',
        () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_standaloneSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketListingPriceDeltaLine(
          48,
          42,
          isSeriesEstimate: true,
          seriesId: _standaloneSeriesId,
        ),
        '▲ 14% above market estimate',
      );
    });

    test('non-blind-box series estimate below uses market estimate wording',
        () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_standaloneSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketListingPriceDeltaLine(
          35,
          42,
          isSeriesEstimate: true,
          seriesId: _standaloneSeriesId,
        ),
        'Below market estimate',
      );
    });

    test('non-blind-box series estimate near uses market estimate wording', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_standaloneSeries()],
          figures: const [],
        ),
      );

      expect(
        formatMarketListingPriceDeltaLine(
          42,
          42,
          isSeriesEstimate: true,
          seriesId: _standaloneSeriesId,
        ),
        '≈ Near market estimate',
      );
    });

    test('returns null when estimate is zero', () {
      expect(
        formatMarketListingPriceDeltaLine(10, 0, isSeriesEstimate: false),
        isNull,
      );
    });
  });

  group('snapshot tier labels', () {
    test('non-blind-box banner and chip use market estimate', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_standaloneSeries()],
          figures: const [],
        ),
      );

      final snapshot = _snapshot(
        level: SnapshotLevel.series,
        figureId: null,
        seriesId: _standaloneSeriesId,
      );

      expect(snapshotTierBBannerLabel(snapshot), 'Market Estimate');
      expect(snapshotTierBEstimateChipLabel(snapshot), 'Market Estimate');
      expect(snapshotTierBInfoSheetTitle(snapshot), 'About this market estimate');
    });

    test('blind-box banner and chip unchanged', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [_blindBoxSeries()],
          figures: const [],
        ),
      );

      final snapshot = _snapshot(
        level: SnapshotLevel.series,
        figureId: null,
      );

      expect(
        snapshotTierBBannerLabel(snapshot),
        kMarketSnapshotInsightsSeriesLevelEstimateLabel,
      );
      expect(
        snapshotTierBEstimateChipLabel(snapshot),
        kMarketSnapshotSeriesEstimateLabel,
      );
      expect(
        snapshotTierBInfoSheetTitle(snapshot),
        kMarketSeriesAverageInfoSheetTitle,
      );
    });
  });
}
