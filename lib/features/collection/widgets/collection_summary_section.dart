import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:flutter/material.dart';

/// Soft glance at the shelf — not a stats dashboard.
@immutable
class CollectionAggregateStats {
  const CollectionAggregateStats({
    required this.inCollection,
    required this.wantListCount,
    required this.completedSeriesCount,
    required this.masterCompleteSeriesCount,
  });

  final int inCollection;
  final int wantListCount;
  final int completedSeriesCount;
  final int masterCompleteSeriesCount;

  factory CollectionAggregateStats.fromSnapshot(CollectionSnapshot s) {
    final (completed, master) = countShelfCompletionTiers(s);
    return CollectionAggregateStats(
      inCollection: s.totalOwnedFigures,
      wantListCount: s.totalWishlistFigures,
      completedSeriesCount: completed,
      masterCompleteSeriesCount: master,
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
    this.collectorTypeName,
  });

  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final VoidCallback? onInsightsTap;
  final String? collectorTypeName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ShelfGlanceStatCell(
                          count: stats.inCollection,
                          label: CollectionSummaryLabels.figures,
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _Dot(scheme: scheme),
                      ),
                      Expanded(
                        child: _ShelfGlanceStatCell(
                          count: stats.wantListCount,
                          label: CollectionSummaryLabels.wishlist,
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ),
                    ],
                  ),
                  if (stats.completedSeriesCount > 0) ...[
                    const SizedBox(height: 14),
                    if (stats.masterCompleteSeriesCount > 0)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ShelfGlanceStatCell(
                              count: stats.completedSeriesCount,
                              label: CollectionSummaryLabels.seriesComplete,
                              scheme: scheme,
                              textTheme: textTheme,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _Dot(scheme: scheme),
                          ),
                          Expanded(
                            child: _ShelfGlanceStatCell(
                              count: stats.masterCompleteSeriesCount,
                              label: CollectionSummaryLabels.masterComplete,
                              scheme: scheme,
                              textTheme: textTheme,
                              emphasizeLabel: true,
                            ),
                          ),
                        ],
                      )
                    else
                      _ShelfGlanceStatCell(
                        count: stats.completedSeriesCount,
                        label: CollectionSummaryLabels.seriesComplete,
                        scheme: scheme,
                        textTheme: textTheme,
                        centered: true,
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
          if (onInsightsTap != null) ...[
            const SizedBox(height: 12),
            _InsightsEntryRow(
              scheme: scheme,
              textTheme: textTheme,
              collectorTypeName: collectorTypeName,
              onTap: onInsightsTap!,
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightsEntryRow extends StatelessWidget {
  const _InsightsEntryRow({
    required this.scheme,
    required this.textTheme,
    required this.onTap,
    this.collectorTypeName,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;
  final String? collectorTypeName;

  @override
  Widget build(BuildContext context) {
    final revealed = collectorTypeName?.trim().isNotEmpty == true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: CollectibleShape.matRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: CollectibleShape.matRadius,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    revealed
                        ? '${CollectorTypeCopy.entryRevealedPrefix}: $collectorTypeName'
                        : CollectorTypeCopy.entryCta,
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

class _ShelfGlanceStatCell extends StatelessWidget {
  const _ShelfGlanceStatCell({
    required this.count,
    required this.label,
    required this.scheme,
    required this.textTheme,
    this.centered = false,
    this.emphasizeLabel = false,
  });

  final int count;
  final String label;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool centered;
  final bool emphasizeLabel;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.deckText(textTheme, scheme).copyWith(
      color: scheme.onSurfaceVariant.withValues(
        alpha: emphasizeLabel ? 0.78 : 0.72,
      ),
      fontWeight: emphasizeLabel ? FontWeight.w600 : FontWeight.w500,
      fontSize: 11.5,
      height: 1.18,
      letterSpacing: 0.02,
    );

    final cell = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.center,
      children: [
        Text(
          '$count',
          textAlign: TextAlign.center,
          style: AppTypography.insightsTotals(textTheme, scheme).copyWith(
            fontWeight: FontWeight.w600,
            height: 1.05,
            color: scheme.onSurface.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.topCenter,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ),
      ],
    );

    if (centered) {
      return Center(child: cell);
    }
    return cell;
  }
}
