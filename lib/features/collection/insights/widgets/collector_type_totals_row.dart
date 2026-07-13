import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
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
                label: CollectorTypeCopy.atAGlanceOwnedFigures,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _MetricTile(
                value: '${stats.completedSeriesCount}',
                label: CollectorTypeCopy.atAGlanceCompletedSeries,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                value: '${stats.masterCompleteSeriesCount}',
                label: CollectorTypeCopy.atAGlanceMasterComplete,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _MetricTile(
                value: '${stats.secretOwned}',
                label: CollectorTypeCopy.atAGlanceSecretsCollected,
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
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerLow.withValues(
          alpha: isDark ? 0.38 : 0.48,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg + 2,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.insightsTotals(textTheme, scheme).copyWith(
                fontSize: 26,
                height: 1.02,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: scheme.onSurface.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.insightsCaption(textTheme, scheme).copyWith(
                fontSize: 11.5,
                letterSpacing: 0.15,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
