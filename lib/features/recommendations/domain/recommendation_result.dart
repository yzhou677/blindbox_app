import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:flutter/foundation.dart';

@immutable
class RecommendationResult {
  const RecommendationResult({
    required this.items,
    required this.fetchedAt,
  });

  final List<RecommendationItem> items;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'items': [for (final item in items) item.toJson()],
      };

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? [
            for (final entry in rawItems)
              if (entry is Map<String, dynamic>)
                RecommendationItem.fromJson(entry),
          ]
        : const <RecommendationItem>[];
    final fetchedAtRaw = json['fetchedAt'] as String?;
    return RecommendationResult(
      items: items,
      fetchedAt: fetchedAtRaw != null
          ? DateTime.tryParse(fetchedAtRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
