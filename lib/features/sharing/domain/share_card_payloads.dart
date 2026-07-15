import 'dart:ui';

import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/foundation.dart';

enum ShareCardImageKind { asset, catalogSeries, localFile }

@immutable
class ShareCardImageRef {
  const ShareCardImageRef({required this.kind, required this.value});

  final ShareCardImageKind kind;
  final String value;
}

@immutable
class CollectorTypeSharePayload {
  const CollectorTypeSharePayload({
    required this.archetypeId,
    required this.displayName,
    required this.label,
    required this.statementTop,
    required this.statementBottom,
    required this.officialExplanation,
    required this.motto,
    required this.metadata,
    required this.mascotAssetPath,
    required this.accent,
  });

  final CollectorTypeArchetypeId archetypeId;
  final String displayName;
  final String label;
  final String statementTop;
  final String statementBottom;
  final String officialExplanation;
  final String motto;
  final String metadata;
  final String mascotAssetPath;
  final Color accent;
}

@immutable
class MasterCompleteSharePayload {
  const MasterCompleteSharePayload({
    required this.label,
    required this.seriesName,
    required this.image,
    required this.metadata,
    required this.regularOwned,
    required this.regularTotal,
    required this.secretOwned,
    required this.secretTotal,
  });

  final String label;
  final String seriesName;
  final ShareCardImageRef image;
  final String metadata;
  final int regularOwned;
  final int regularTotal;
  final int secretOwned;
  final int secretTotal;
}

@immutable
class ShelfShareSeriesItem {
  const ShelfShareSeriesItem({
    required this.seriesId,
    required this.seriesName,
    required this.ipName,
    required this.image,
    required this.regularProgress,
    required this.isCompleted,
    required this.isMasterComplete,
  });

  final String seriesId;
  final String seriesName;
  final String ipName;
  final ShareCardImageRef image;
  final double regularProgress;
  final bool isCompleted;
  final bool isMasterComplete;
}

@immutable
class ShelfSharePayload {
  const ShelfSharePayload({
    required this.label,
    required this.collectorTypeName,
    required this.ownedFigureCount,
    required this.trackedSeriesCount,
    required this.completedSeriesCount,
    required this.masterCompleteSeriesCount,
    required this.overallRegularProgress,
    required this.featuredSeries,
    required this.generatedAt,
  });

  final String label;
  final String? collectorTypeName;
  final int ownedFigureCount;
  final int trackedSeriesCount;
  final int completedSeriesCount;
  final int masterCompleteSeriesCount;
  final int overallRegularProgress;
  final List<ShelfShareSeriesItem> featuredSeries;
  final DateTime generatedAt;
}
