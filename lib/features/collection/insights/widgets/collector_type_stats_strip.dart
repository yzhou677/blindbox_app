import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_brand_donut.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_top_series_list.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_totals_row.dart';
import 'package:flutter/material.dart';

class CollectorTypeStatsStrip extends StatelessWidget {
  const CollectorTypeStatsStrip({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                CollectorTypeCopy.statsSectionTitle,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 12),
              CollectorTypeTotalsRow(stats: stats),
              if (stats.brandBreakdown.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: CollectorTypeBrandDonut(
                    brandBreakdown: stats.brandBreakdown,
                  ),
                ),
              ],
              if (stats.topSeries.isNotEmpty) ...[
                const SizedBox(height: 16),
                CollectorTypeTopSeriesList(seriesNames: stats.topSeries),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
