import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Aggregates for the summary strip (derived from [CollectionSnapshot]).
@immutable
class CollectionAggregateStats {
  const CollectionAggregateStats({
    required this.ownedSlots,
    required this.wishlistSlots,
    required this.avgCompletionPercent,
  });

  final int ownedSlots;
  final int wishlistSlots;
  final int avgCompletionPercent;

  factory CollectionAggregateStats.fromSnapshot(CollectionSnapshot s) {
    return CollectionAggregateStats(
      ownedSlots: s.totalOwnedFigures,
      wishlistSlots: s.totalWishlistFigures,
      avgCompletionPercent: s.averageCompletionPercent,
    );
  }
}

/// Collector dashboard strip — fixed rhythm so values and captions align.
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
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
                )!.withValues(alpha: isDark ? 0.38 : 0.48),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: SizedBox(
                height: FeedRhythm.collectionSummaryMetricStripHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricCell(
                        label: 'On shelf',
                        value: '${stats.ownedSlots}',
                        hint: 'Owned',
                      ),
                    ),
                    _Dot(scheme: scheme),
                    Expanded(
                      child: _MetricCell(
                        label: 'Hunt list',
                        value: '${stats.wishlistSlots}',
                        hint: 'Wishlist',
                      ),
                    ),
                    _Dot(scheme: scheme),
                    Expanded(
                      child: _MetricCell(
                        label: 'Avg shelf',
                        value: '${stats.avgCompletionPercent}%',
                        hint: 'Per series',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (shelfMoodLine != null && shelfMoodLine!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              shelfMoodLine!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                height: 1.4,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 0.06,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          strutStyle: const StrutStyle(fontSize: 30, height: 1.05, forceStrutHeight: true),
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.45,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            height: 1.15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
