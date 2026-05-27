import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_brand_donut.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_top_series_list.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_totals_row.dart';
import 'package:flutter/material.dart';

class CollectorTypeStatsStrip extends StatelessWidget {
  const CollectorTypeStatsStrip({super.key, required this.stats});

  // Vertical rhythm within the stats card — deliberately tighter than
  // page-level FeedRhythm constants to create a dense-but-readable stat block.
  static const double _titleToTotals = AppSpacing.lg - 2; // 14
  static const double _totalsToDonut = AppSpacing.xxl - 2; // 22
  static const double _donutToTopSeries = AppSpacing.xxl + AppSpacing.xs; // 28 ≈ 26

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: FeedRhythm.blockGapMedium),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: CollectibleShape.matRadius,
            color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
              AppSpacing.pageHorizontal,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  CollectorTypeCopy.statsSectionTitle,
                  style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
                ),
                const SizedBox(height: _titleToTotals),
                CollectorTypeTotalsRow(stats: stats),
                if (stats.brandBreakdown.isNotEmpty) ...[
                  const SizedBox(height: _totalsToDonut),
                  Text(
                    'Brands',
                    style: AppTypography.insightsCaption(textTheme, scheme),
                  ),
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                  Center(
                    child: CollectorTypeBrandDonut(
                      brandBreakdown: stats.brandBreakdown,
                    ),
                  ),
                ],
                if (stats.topSeries.isNotEmpty) ...[
                  const SizedBox(height: _donutToTopSeries),
                  Divider(
                    thickness: 0,
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Top series',
                    style: AppTypography.insightsCaption(textTheme, scheme),
                  ),
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                  CollectorTypeTopSeriesList(seriesNames: stats.topSeries),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
