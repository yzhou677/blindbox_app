import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_palette.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_brand_donut.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_shelf_progress_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_totals_row.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_dashboard_panel.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:flutter/material.dart';

class CollectorTypeStatsStrip extends StatelessWidget {
  const CollectorTypeStatsStrip({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: FeedRhythm.insightsHeroToStats),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InsightsDashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    CollectorTypeCopy.statsSectionTitle,
                    style: CollectibleTypography.shelfSeriesTitle(
                      textTheme,
                      scheme,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CollectorTypeTotalsRow(stats: stats),
                ],
              ),
            ),
            const SizedBox(height: FeedRhythm.insightsStatsToProgress),
            CollectorTypeShelfProgressCard(stats: stats),
            if (stats.brandBreakdown.isNotEmpty) ...[
              const SizedBox(height: FeedRhythm.insightsProgressToBrand),
              InsightsDashboardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Brand distribution',
                      style: CollectibleTypography.shelfSeriesTitle(
                        textTheme,
                        scheme,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _BrandDistributionRow(brandBreakdown: stats.brandBreakdown),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandDistributionRow extends StatelessWidget {
  const _BrandDistributionRow({required this.brandBreakdown});

  final Map<String, int> brandBreakdown;

  @override
  Widget build(BuildContext context) {
    final entries = brandBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (entries.isEmpty || total <= 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = CollectorTypePalette.sectorColors;

    // Single brand: quiet emphasis — no oversized empty donut.
    if (entries.length == 1) {
      final entry = entries.first;
      final label =
          MarketTaxonomy.brandById(entry.key)?.displayLabel ?? entry.key;
      return _SingleBrandEmphasis(
        color: colors.first,
        label: label,
        percent: 100,
        figureCount: entry.value,
        textTheme: textTheme,
        scheme: scheme,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CollectorTypeBrandDonut(
          brandBreakdown: brandBreakdown,
          size: 112,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length && i < 5; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _BrandLegendLine(
                  color: colors[i % colors.length],
                  label: MarketTaxonomy.brandById(entries[i].key)?.displayLabel ??
                      entries[i].key,
                  percent: ((entries[i].value / total) * 100).round(),
                  textTheme: textTheme,
                  scheme: scheme,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SingleBrandEmphasis extends StatelessWidget {
  const _SingleBrandEmphasis({
    required this.color,
    required this.label,
    required this.percent,
    required this.figureCount,
    required this.textTheme,
    required this.scheme,
  });

  final Color color;
  final String label;
  final int percent;
  final int figureCount;
  final TextTheme textTheme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: isDark ? 0.14 : 0.10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.88),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.shelfSeriesTitle(
                      textTheme,
                      scheme,
                    ).copyWith(
                      fontSize: 17,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$figureCount ${figureCount == 1 ? 'figure' : 'figures'}',
                    style: AppTypography.insightsCaption(textTheme, scheme)
                        .copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.64),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$percent%',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: scheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLegendLine extends StatelessWidget {
  const _BrandLegendLine({
    required this.color,
    required this.label,
    required this.percent,
    required this.textTheme,
    required this.scheme,
  });

  final Color color;
  final String label;
  final int percent;
  final TextTheme textTheme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ),
        Text(
          '$percent%',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}
