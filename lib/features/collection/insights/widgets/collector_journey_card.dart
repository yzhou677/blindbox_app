import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_dashboard_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectorJourneyCard extends ConsumerWidget {
  const CollectorJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(collectorJourneySummaryProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InsightsDashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CollectorTypeCopy.journeyTitle,
            style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CollectorTypeCopy.journeySubtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!summary.hasHistory)
            Text(
              CollectorTypeCopy.journeyEmpty,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              ),
            )
          else ...[
            _MetricLine(
              label: 'IPs explored over time',
              value: summary.ipUniversesExplored.toString(),
            ),
            if (summary.topIps.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                CollectorTypeCopy.journeyMostExploredIpsTitle,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final entry in summary.topIps)
                    _IpChip(label: entry.label),
                ],
              ),
            ],
            if (summary.journeyAgeLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _MetricLine(
                label: 'Journey began',
                value: summary.journeyAgeLabel!,
              ),
            ],
          ],
        ],
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
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
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

class _IpChip extends StatelessWidget {
  const _IpChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.primaryContainer.withValues(alpha: 0.45),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}
