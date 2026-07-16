import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/presentation/completion_metric_tooltips.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/widgets/info_tooltip_icon.dart';
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

@immutable
class CollectionSummaryMetricLabels {
  const CollectionSummaryMetricLabels({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.quaternary,
    this.tertiaryTooltip = CompletionMetricTooltips.completedSeries,
    this.showSecondRow = true,
  });

  final String primary;
  final String secondary;
  final String tertiary;
  final String quaternary;
  final String? tertiaryTooltip;
  final bool showSecondRow;

  static const collection = CollectionSummaryMetricLabels(
    primary: CollectionSummaryLabels.figures,
    secondary: CollectionSummaryLabels.wishlist,
    tertiary: CollectionSummaryLabels.seriesComplete,
    quaternary: CollectionSummaryLabels.masterComplete,
  );

  static const wishlist = CollectionSummaryMetricLabels(
    primary: 'Wishlisted Series',
    secondary: 'Wishlisted Figures',
    tertiary: '',
    quaternary: '',
    tertiaryTooltip: null,
    showSecondRow: false,
  );
}

class CollectionSummarySection extends StatelessWidget {
  const CollectionSummarySection({
    super.key,
    required this.stats,
    this.shelfMoodLine,
    this.memoryWhisper,
    this.onInsightsTap,
    this.onSummaryCardTap,
    this.collectorTypeName,
    this.metricLabels = CollectionSummaryMetricLabels.collection,
    this.cardVerticalPadding = FeedRhythm.collectionSummaryCardVerticalPadding,
    this.cardTopPadding,
    this.cardBottomPadding,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      0,
      AppSpacing.pageHorizontal,
      FeedRhythm.collectionSummaryToShelfHeader,
    ),
  });

  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final VoidCallback? onInsightsTap;
  final VoidCallback? onSummaryCardTap;
  final String? collectorTypeName;
  final CollectionSummaryMetricLabels metricLabels;
  final double cardVerticalPadding;
  final double? cardTopPadding;
  final double? cardBottomPadding;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryStatsCard(
            scheme: scheme,
            isDark: isDark,
            onTap: onSummaryCardTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                cardTopPadding ?? cardVerticalPadding,
                18,
                cardBottomPadding ?? cardVerticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MetricRow(
                    scheme: scheme,
                    textTheme: textTheme,
                    children: [
                      _ShelfGlanceStatCell(
                        count: stats.inCollection,
                        label: metricLabels.primary,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                      _ShelfGlanceStatCell(
                        count: stats.wantListCount,
                        label: metricLabels.secondary,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                  if (metricLabels.showSecondRow) ...[
                    const SizedBox(
                      height: FeedRhythm.collectionSummaryMetricRowGap,
                    ),
                    _MetricRow(
                      scheme: scheme,
                      textTheme: textTheme,
                      children: [
                        _ShelfGlanceStatCell(
                          count: stats.completedSeriesCount,
                          label: metricLabels.tertiary,
                          scheme: scheme,
                          textTheme: textTheme,
                          tooltip: metricLabels.tertiaryTooltip,
                          muted: stats.completedSeriesCount == 0,
                        ),
                        _ShelfGlanceStatCell(
                          count: stats.masterCompleteSeriesCount,
                          label: metricLabels.quaternary,
                          scheme: scheme,
                          textTheme: textTheme,
                          muted: stats.masterCompleteSeriesCount == 0,
                          emphasizeLabel: stats.masterCompleteSeriesCount > 0,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (shelfMoodLine != null && shelfMoodLine!.trim().isNotEmpty) ...[
            const SizedBox(height: FeedRhythm.collectionSummaryToEditorial),
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
          if (memoryWhisper != null && memoryWhisper!.trim().isNotEmpty) ...[
            const SizedBox(height: FeedRhythm.collectionSummaryEditorialGap),
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
            const SizedBox(height: AppSpacing.lg),
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

class _SummaryStatsCard extends StatelessWidget {
  const _SummaryStatsCard({
    required this.scheme,
    required this.isDark,
    required this.child,
    this.onTap,
  });

  final ColorScheme scheme;
  final bool isDark;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: CollectibleShape.shellRadius,
      color: scheme.surfaceContainerLow,
      border: Border.all(
        color: Color.lerp(
          scheme.outlineVariant,
          scheme.primary,
          isDark ? 0.12 : 0.18,
        )!,
      ),
    );

    if (onTap == null) {
      return DecoratedBox(
        key: const Key('collection_summary_stats_card'),
        decoration: decoration,
        child: child,
      );
    }

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collection_summary_stats_card'),
          onTap: onTap,
          borderRadius: CollectibleShape.shellRadius,
          child: Ink(decoration: decoration, child: child),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.scheme,
    required this.textTheme,
    required this.children,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final List<_ShelfGlanceStatCell> children;

  @override
  Widget build(BuildContext context) {
    assert(children.length == 2);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: children[0]),
          Center(child: _Dot(scheme: scheme)),
          Expanded(child: children[1]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.2),
        ),
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
    this.muted = false,
    this.emphasizeLabel = false,
    this.tooltip,
  });

  final int count;
  final String label;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool muted;
  final bool emphasizeLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final countAlpha = muted ? 0.36 : 0.92;
    final labelAlpha = muted
        ? 0.38
        : emphasizeLabel
        ? 0.78
        : 0.72;

    final labelStyle = AppTypography.deckText(textTheme, scheme).copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: labelAlpha),
      fontWeight: emphasizeLabel ? FontWeight.w600 : FontWeight.w500,
      fontSize: 11.5,
      height: 1.18,
      letterSpacing: 0.02,
    );

    final countStyle = AppTypography.insightsTotals(textTheme, scheme).copyWith(
      fontWeight: FontWeight.w600,
      height: 1.0,
      color: scheme.onSurface.withValues(alpha: countAlpha),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: FeedRhythm.collectionSummaryCountHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: countStyle,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: FeedRhythm.collectionSummaryLabelHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: _MetricLabel(
              label: label,
              style: labelStyle,
              tooltip: tooltip,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel({required this.label, required this.style, this.tooltip});

  final String label;
  final TextStyle style;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (tooltip == null) return text;

    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: text),
        const SizedBox(width: 4),
        InfoTooltipIcon(
          message: tooltip!,
          size: 13,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.54),
        ),
      ],
    );
  }
}
