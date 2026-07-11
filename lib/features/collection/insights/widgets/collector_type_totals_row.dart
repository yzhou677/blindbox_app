import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';

/// Quick statistics summary for Insights — counts only, no progress chrome.
class CollectorTypeTotalsRow extends StatelessWidget {
  const CollectorTypeTotalsRow({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                value: '${stats.totalOwned}',
                label: CollectionVocabulary.figures,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                value: '${stats.totalWishlist}',
                label: CollectionVocabulary.wishlist,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                value: '${stats.trackedSeries}',
                label: CollectionVocabulary.series,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                value: '${stats.secretOwned}',
                label: CollectionVocabulary.secretFigure,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.55 : 0.72),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.insightsTotals(textTheme, scheme).copyWith(
                fontSize: 22,
                height: 1.05,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.insightsCaption(textTheme, scheme),
            ),
          ],
        ),
      ),
    );
  }
}
