import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/domain/shelf_value_summary.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
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
    this.memoryWhisper,
    this.onInsightsTap,
    this.shelfValue,
  });

  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final VoidCallback? onInsightsTap;

  /// When provided and [ShelfValueSummary.hasAnyValue], shows value glance in
  /// the summary card.
  final ShelfValueSummary? shelfValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final valueData = shelfValue;
    final showValue = valueData != null && valueData.hasAnyValue;
    final showInsightsEntry = onInsightsTap != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xs + 2, // 6 — tighter top than belowTabAppBar so card sits close to section header
        AppSpacing.pageHorizontal,
        FeedRhythm.blockGapMedium, // 18
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: CollectibleShape.shellRadius,
              color: scheme.surfaceContainerLow,
              border: Border.all(
                color: Color.lerp(
                  scheme.outlineVariant,
                  scheme.primary,
                  isDark ? 0.12 : 0.18,
                )!,
              ),
            ),
            child: Padding(
              // Horizontal 18 is intentionally narrower than pageHorizontal (20)
              // to give the metric strip a slightly inset look within the card.
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: FeedRhythm.collectionSummaryMetricStripHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ShelfGlanceStat(
                          count: stats.inCollection,
                          label: 'in collection',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _Dot(scheme: scheme),
                        ),
                        _ShelfGlanceStat(
                          count: stats.wantListCount,
                          label: 'wishlist',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ),
                  if (showValue) ...[
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 10),
                    _ShelfValueGlance(
                      summary: valueData,
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ],
                  if (showInsightsEntry) ...[
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 6),
                    _SummaryNavEntryRow(
                      scheme: scheme,
                      textTheme: textTheme,
                      label: CollectorTypeCopy.homeInsightsEntry,
                      icon: Icons.insights_outlined,
                      onTap: onInsightsTap!,
                    ),
                  ],
                ],
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
          if (memoryWhisper != null && memoryWhisper!.trim().isNotEmpty)
            ...[
            const SizedBox(height: 6),
            Text(
              memoryWhisper!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
                height: 1.32,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryNavEntryRow extends StatelessWidget {
  const _SummaryNavEntryRow({
    required this.scheme,
    required this.textTheme,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: CollectibleShape.insetRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: scheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
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
          style: AppTypography.insightsTotals(textTheme, scheme).copyWith(
            fontWeight: FontWeight.w600,
            height: 1.05,
            color: scheme.onSurface.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(
          label,
          style: AppTypography.deckText(textTheme, scheme).copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _ShelfValueGlance extends StatelessWidget {
  const _ShelfValueGlance({
    required this.summary,
    required this.scheme,
    required this.textTheme,
  });

  final ShelfValueSummary summary;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final valueLabel = '~${formatShelfValueUsd(summary.totalValueUsd)}';
    final coverageLabel =
        'Based on ${summary.valuedCount} of ${summary.ownedCount} figures';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Est. shelf value',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              valueLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            coverageLabel,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
