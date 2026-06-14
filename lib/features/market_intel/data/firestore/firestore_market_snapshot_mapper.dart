import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore collection for persisted sold-data market intelligence.
const String kMarketSnapshotsCollection = 'market_snapshots';

MarketSnapshot? mapFirestoreMarketSnapshot(
  String docId,
  Map<String, dynamic> data,
) {
  try {
    final level = _parseLevel(_readString(data, 'level'));
    if (level == null) return null;

    final seriesId = _readString(data, 'seriesId');
    if (seriesId.isEmpty) return null;

    final estimatedValueUsd = _readDouble(data, 'estimatedValueUsd');
    if (estimatedValueUsd <= 0) return null;

    final confidence = _parseConfidence(_readString(data, 'confidence'));
    if (confidence == null) return null;

    final recentSalesCount = _readInt(data, 'recentSalesCount');
    if (recentSalesCount < 0) return null;

    final computedAt = _readTimestamp(data, 'computedAt');
    if (computedAt == null) return null;

    final figureIdRaw = _readString(data, 'figureId');
    final figureId = figureIdRaw.isEmpty ? null : figureIdRaw;

    if (level == SnapshotLevel.figure &&
        (figureId == null || figureId.isEmpty)) {
      return null;
    }

    if (level == SnapshotLevel.series && figureId != null) {
      return null;
    }

    final id = _readString(data, 'id');
    final resolvedId = id.isNotEmpty ? id : docId;
    if (resolvedId.isEmpty) return null;

    return MarketSnapshot(
      id: resolvedId,
      level: level,
      figureId: level == SnapshotLevel.figure ? figureId : null,
      seriesId: seriesId,
      estimatedValueUsd: estimatedValueUsd,
      trend: _parseTrend(_readString(data, 'trend')),
      confidence: confidence,
      recentSalesCount: recentSalesCount,
      priceRangeMinUsd: _readOptionalDouble(data, 'priceRangeMinUsd'),
      priceRangeMaxUsd: _readOptionalDouble(data, 'priceRangeMaxUsd'),
      computedAt: computedAt,
    );
  } on Object catch (e, st) {
    debugPrint('mapFirestoreMarketSnapshot: skipped $docId: $e\n$st');
    return null;
  }
}

String _readString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return '';
  return value.toString().trim();
}

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

double? _readOptionalDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int _readInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? -1;
  return -1;
}

DateTime? _readTimestamp(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  return null;
}

SnapshotLevel? _parseLevel(String value) {
  return switch (value.toLowerCase()) {
    'figure' => SnapshotLevel.figure,
    'series' => SnapshotLevel.series,
    _ => null,
  };
}

MarketTrend _parseTrend(String value) {
  return switch (value.toLowerCase()) {
    'rising' => MarketTrend.rising,
    'falling' => MarketTrend.falling,
    'stable' => MarketTrend.stable,
    _ => MarketTrend.unknown,
  };
}

SnapshotConfidence? _parseConfidence(String value) {
  return switch (value.toLowerCase()) {
    'high' => SnapshotConfidence.high,
    'low' => SnapshotConfidence.low,
    _ => null,
  };
}
