import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter_test/flutter_test.dart';

MarketSnapshot _snapshot({
  SnapshotLevel level = SnapshotLevel.figure,
  String? figureId = 'fig_luck',
  int recentSalesCount = 18,
  double? priceRangeMinUsd = 38,
  double? priceRangeMaxUsd = 48,
  SnapshotConfidence confidence = SnapshotConfidence.high,
  DateTime? computedAt,
}) {
  return MarketSnapshot(
    id: figureId ?? 'series_bie',
    level: level,
    figureId: level == SnapshotLevel.figure ? figureId : null,
    seriesId: 'series_bie',
    estimatedValueUsd: 42,
    trend: MarketTrend.rising,
    confidence: confidence,
    recentSalesCount: recentSalesCount,
    priceRangeMinUsd: priceRangeMinUsd,
    priceRangeMaxUsd: priceRangeMaxUsd,
    computedAt: computedAt ?? DateTime.utc(2026, 6, 15),
  );
}

void main() {
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

    test('series fallback uses using-series-estimate label and sales', () {
      expect(
        formatMarketSnapshotDiscoverSummaryLine(
          _snapshot(
            level: SnapshotLevel.series,
            figureId: null,
            recentSalesCount: 4,
            confidence: SnapshotConfidence.low,
          ),
        ),
        'Using Series Estimate · \$42 · 4 sales',
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

    test('appends asterisk for low confidence', () {
      expect(
        formatMarketSnapshotSalesLine(
          _snapshot(confidence: SnapshotConfidence.low, recentSalesCount: 4),
        ),
        '4 sales*',
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
}
