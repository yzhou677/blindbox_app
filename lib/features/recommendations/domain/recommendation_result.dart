import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:flutter/foundation.dart';

@immutable
class RecommendationResult {
  const RecommendationResult({
    required this.items,
    this.profileHash,
  });

  final List<RecommendationItem> items;

  /// Collection profile snapshot this result was computed for.
  final String? profileHash;

  Map<String, dynamic> toJson() => {
        if (profileHash != null) 'profileHash': profileHash,
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
    return RecommendationResult(
      items: items,
      profileHash: json['profileHash'] as String?,
    );
  }
}
