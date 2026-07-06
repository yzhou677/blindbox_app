import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:flutter/foundation.dart';

@immutable
class RecommendationItem {
  const RecommendationItem({
    required this.seriesId,
    required this.reasonType,
    this.reasonMeta,
    this.series,
  });

  final String seriesId;
  final String reasonType;
  final String? reasonMeta;
  final catalog.CatalogSeries? series;

  RecommendationItem copyWith({
    catalog.CatalogSeries? series,
  }) {
    return RecommendationItem(
      seriesId: seriesId,
      reasonType: reasonType,
      reasonMeta: reasonMeta,
      series: series ?? this.series,
    );
  }

  Map<String, dynamic> toJson() => {
        'seriesId': seriesId,
        'reasonType': reasonType,
        if (reasonMeta != null) 'reasonMeta': reasonMeta,
      };

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      seriesId: json['seriesId'] as String,
      reasonType: json['reasonType'] as String,
      reasonMeta: json['reasonMeta'] as String?,
    );
  }
}
