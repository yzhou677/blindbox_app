import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/presentation/completion_metric_tooltips.dart';
import 'package:blindbox_app/features/collection/widgets/info_tooltip_icon.dart';
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
                tooltip: CompletionMetricTooltips.completedSeries,
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
                tooltip: CompletionMetricTooltips.masterComplete,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _MetricTile(
                value: '${stats.secretOwned}',
                label: CollectorTypeCopy.atAGlanceSecretsCollected,
                tooltip: CompletionMetricTooltips.secretsCollected,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label, this.tooltip});

  final String value;
  final String label;
  final String? tooltip;

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
            _MetricLabel(
              label: label,
              tooltip: tooltip,
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
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
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
