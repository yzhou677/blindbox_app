import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Soft glance at the shelf — not a stats dashboard.
@immutable
class CollectionAggregateStats {
  const CollectionAggregateStats({
    required this.inCollection,
    required this.wantListCount,
  });

  final int inCollection;
  final int wantListCount;

  factory CollectionAggregateStats.fromSnapshot(CollectionSnapshot s) {
    return CollectionAggregateStats(
      inCollection: s.totalOwnedFigures,
      wantListCount: s.totalWishlistFigures,
    );
  }
}

class CollectionSummarySection extends StatelessWidget {
  const CollectionSummarySection({
    super.key,
    required this.stats,
    this.shelfMoodLine,
  });

  final CollectionAggregateStats stats;
  final String? shelfMoodLine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: CollectibleShape.shellRadius,
              color: scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.92 : 1),
              border: Border.all(
                color: Color.lerp(
                  scheme.outlineVariant,
                  scheme.primary,
                  isDark ? 0.12 : 0.18,
                )!.withValues(alpha: isDark ? 0.32 : 0.42),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: SizedBox(
                height: FeedRhythm.collectionSummaryMetricStripHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ShelfGlanceStat(
                      count: stats.inCollection,
                      label: 'In collection',
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _Dot(scheme: scheme),
                    ),
                    _ShelfGlanceStat(
                      count: stats.wantListCount,
                      label: 'Wish list',
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (shelfMoodLine != null && shelfMoodLine!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              shelfMoodLine!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                height: 1.38,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.2),
      ),
    );
  }
}

class _ShelfGlanceStat extends StatelessWidget {
  const _ShelfGlanceStat({
    required this.count,
    required this.label,
    required this.scheme,
    required this.textTheme,
  });

  final int count;
  final String label;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$count',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.35,
            height: 1.05,
            color: scheme.onSurface.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
