import 'package:blindbox_app/features/market_intel/data/firestore/firestore_market_snapshot_mapper.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapFirestoreMarketSnapshot', () {
    test('parses valid figure snapshot with all fields', () {
      final mapped = mapFirestoreMarketSnapshot(
        'lucky_big_into_energy_popmart',
        {
          'level': 'figure',
          'figureId': 'lucky_big_into_energy_popmart',
          'seriesId': 'big_into_energy_popmart',
          'estimatedValueUsd': 42.5,
          'trend': 'rising',
          'confidence': 'high',
          'recentSalesCount': 18,
          'priceRangeMinUsd': 35,
          'priceRangeMaxUsd': 55,
          'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14, 12)),
        },
      );

      expect(mapped, isNotNull);
      final snapshot = mapped!;
      expect(snapshot.id, 'lucky_big_into_energy_popmart');
      expect(snapshot.level, SnapshotLevel.figure);
      expect(snapshot.figureId, 'lucky_big_into_energy_popmart');
      expect(snapshot.seriesId, 'big_into_energy_popmart');
      expect(snapshot.estimatedValueUsd, 42.5);
      expect(snapshot.trend, MarketTrend.rising);
      expect(snapshot.confidence, SnapshotConfidence.high);
      expect(snapshot.recentSalesCount, 18);
      expect(snapshot.priceRangeMinUsd, 35);
      expect(snapshot.priceRangeMaxUsd, 55);
      expect(snapshot.computedAt, DateTime.utc(2026, 6, 14, 12));
      expect(snapshot.isSeriesEstimate, isFalse);
    });

    test('parses valid series snapshot without figureId', () {
      final mapped = mapFirestoreMarketSnapshot(
        'big_into_energy_popmart',
        {
          'level': 'series',
          'seriesId': 'big_into_energy_popmart',
          'estimatedValueUsd': 28,
          'confidence': 'low',
          'recentSalesCount': 5,
          'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
        },
      );

      expect(mapped, isNotNull);
      final snapshot = mapped!;
      expect(snapshot.level, SnapshotLevel.series);
      expect(snapshot.figureId, isNull);
      expect(snapshot.trend, MarketTrend.unknown);
      expect(snapshot.isSeriesEstimate, isTrue);
    });

    test('defaults missing trend to unknown', () {
      final mapped = mapFirestoreMarketSnapshot(
        'lucky_big_into_energy_popmart',
        {
          'level': 'figure',
          'figureId': 'lucky_big_into_energy_popmart',
          'seriesId': 'big_into_energy_popmart',
          'estimatedValueUsd': 42,
          'confidence': 'high',
          'recentSalesCount': 18,
          'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
        },
      );

      expect(mapped, isNotNull);
      expect(mapped!.trend, MarketTrend.unknown);
    });

    test('defaults unrecognized trend string to unknown', () {
      final mapped = mapFirestoreMarketSnapshot(
        'lucky_big_into_energy_popmart',
        {
          'level': 'figure',
          'figureId': 'lucky_big_into_energy_popmart',
          'seriesId': 'big_into_energy_popmart',
          'estimatedValueUsd': 42,
          'trend': 'not-a-trend',
          'confidence': 'high',
          'recentSalesCount': 18,
          'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
        },
      );

      expect(mapped, isNotNull);
      expect(mapped!.trend, MarketTrend.unknown);
    });

    test('maps each supported trend value', () {
      for (final entry in {
        'rising': MarketTrend.rising,
        'falling': MarketTrend.falling,
        'stable': MarketTrend.stable,
        'unknown': MarketTrend.unknown,
      }.entries) {
        final mapped = mapFirestoreMarketSnapshot('fig_1', {
          'level': 'figure',
          'figureId': 'fig_1',
          'seriesId': 'series_1',
          'estimatedValueUsd': 10,
          'trend': entry.key,
          'confidence': 'high',
          'recentSalesCount': 3,
          'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
        });
        expect(mapped?.trend, entry.value, reason: entry.key);
      }
    });
  });

  group('mapFirestoreMarketSnapshot guards', () {
    test('skips document without seriesId', () {
      final mapped = mapFirestoreMarketSnapshot('fig_1', {
        'level': 'figure',
        'figureId': 'fig_1',
        'estimatedValueUsd': 42,
        'confidence': 'high',
        'recentSalesCount': 3,
        'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
      });
      expect(mapped, isNull);
    });

    test('skips document with zero estimatedValueUsd', () {
      final mapped = mapFirestoreMarketSnapshot('fig_1', {
        'level': 'figure',
        'figureId': 'fig_1',
        'seriesId': 'series_1',
        'estimatedValueUsd': 0,
        'confidence': 'high',
        'recentSalesCount': 3,
        'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
      });
      expect(mapped, isNull);
    });

    test('skips document without computedAt', () {
      final mapped = mapFirestoreMarketSnapshot('fig_1', {
        'level': 'figure',
        'figureId': 'fig_1',
        'seriesId': 'series_1',
        'estimatedValueUsd': 42,
        'confidence': 'high',
        'recentSalesCount': 3,
      });
      expect(mapped, isNull);
    });

    test('skips document with invalid level', () {
      final mapped = mapFirestoreMarketSnapshot('fig_1', {
        'level': 'listing',
        'figureId': 'fig_1',
        'seriesId': 'series_1',
        'estimatedValueUsd': 42,
        'confidence': 'high',
        'recentSalesCount': 3,
        'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
      });
      expect(mapped, isNull);
    });

    test('skips document with invalid confidence', () {
      final mapped = mapFirestoreMarketSnapshot('fig_1', {
        'level': 'figure',
        'figureId': 'fig_1',
        'seriesId': 'series_1',
        'estimatedValueUsd': 42,
        'confidence': 'medium',
        'recentSalesCount': 3,
        'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
      });
      expect(mapped, isNull);
    });

    test('skips figure document without figureId', () {
      final mapped = mapFirestoreMarketSnapshot('fig_1', {
        'level': 'figure',
        'seriesId': 'series_1',
        'estimatedValueUsd': 42,
        'confidence': 'high',
        'recentSalesCount': 3,
        'computedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 14)),
      });
      expect(mapped, isNull);
    });
  });
}
