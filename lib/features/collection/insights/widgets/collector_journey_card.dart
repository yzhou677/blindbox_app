import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectorJourneyCard extends ConsumerWidget {
  const CollectorJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(collectorJourneySummaryProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: CollectibleShape.matRadius,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CollectorTypeCopy.journeyTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              CollectorTypeCopy.journeySubtitle,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: FeedRhythm.blockGapMedium),
            if (!summary.hasHistory)
              Text(
                CollectorTypeCopy.journeyEmpty,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              _MetricLine(
                label: 'IPs explored over time',
                value: summary.ipUniversesExplored.toString(),
              ),
              if (summary.seriesExploredOverTime > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                _MetricLine(
                  label: 'Series explored over time',
                  value: summary.seriesExploredOverTime.toString(),
                ),
              ],
              if (summary.topIps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Most explored',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final entry in summary.topIps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '${entry.label} (${entry.seriesCount})',
                      style: textTheme.bodyMedium,
                    ),
                  ),
              ],
              if (summary.journeyAgeLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                _MetricLine(
                  label: 'Journey began',
                  value: summary.journeyAgeLabel!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
