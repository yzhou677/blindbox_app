import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:flutter/foundation.dart';

@immutable
class RecommendationItem {
  const RecommendationItem({
    required this.seriesId,
    required this.primaryReasonType,
    this.primaryReasonMeta,
    this.secondaryReasonType,
    this.secondaryReasonMeta,
    this.series,
  });

  final String seriesId;
  final String primaryReasonType;
  final String? primaryReasonMeta;
  final String? secondaryReasonType;
  final String? secondaryReasonMeta;
  final catalog.CatalogSeries? series;

  /// Legacy alias for [primaryReasonType] (cached payloads, tests).
  String get reasonType => primaryReasonType;

  /// Legacy alias for [primaryReasonMeta].
  String? get reasonMeta => primaryReasonMeta;

  RecommendationItem copyWith({
    catalog.CatalogSeries? series,
  }) {
    return RecommendationItem(
      seriesId: seriesId,
      primaryReasonType: primaryReasonType,
      primaryReasonMeta: primaryReasonMeta,
      secondaryReasonType: secondaryReasonType,
      secondaryReasonMeta: secondaryReasonMeta,
      series: series ?? this.series,
    );
  }

  Map<String, dynamic> toJson() => {
        'seriesId': seriesId,
        'primaryReasonType': primaryReasonType,
        if (primaryReasonMeta != null) 'primaryReasonMeta': primaryReasonMeta,
        if (secondaryReasonType != null)
          'secondaryReasonType': secondaryReasonType,
        if (secondaryReasonMeta != null)
          'secondaryReasonMeta': secondaryReasonMeta,
        // Legacy fields mirror primary for older clients and cached rows.
        'reasonType': primaryReasonType,
        if (primaryReasonMeta != null) 'reasonMeta': primaryReasonMeta,
      };

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    final primaryType = json['primaryReasonType'] as String? ??
        json['reasonType'] as String?;
    if (primaryType == null) {
      throw FormatException('Missing recommendation reason for series');
    }

    return RecommendationItem(
      seriesId: json['seriesId'] as String,
      primaryReasonType: primaryType,
      primaryReasonMeta: json['primaryReasonMeta'] as String? ??
          json['reasonMeta'] as String?,
      secondaryReasonType: json['secondaryReasonType'] as String?,
      secondaryReasonMeta: json['secondaryReasonMeta'] as String?,
    );
  }

  static RecommendationItem? tryFromJson(Map<String, dynamic> json) {
    try {
      return RecommendationItem.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
