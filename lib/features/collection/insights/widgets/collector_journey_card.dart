import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_dashboard_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Story card for how the shelf has unfolded — narrative rhythm, not key-value rows.
class CollectorJourneyCard extends ConsumerWidget {
  const CollectorJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(collectorJourneySummaryProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InsightsDashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CollectorTypeCopy.journeyTitle,
            style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CollectorTypeCopy.journeySubtitle,
            style: AppTypography.insightsFlavor(textTheme, scheme).copyWith(
              fontSize: 13,
              height: 1.4,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
          if (!summary.hasHistory) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              CollectorTypeCopy.journeyEmpty,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
          ] else ...[
            if (summary.journeyAgeLabel != null) ...[
              const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
              _StoryBeat(
                label: CollectorTypeCopy.journeyStartedLabel,
                child: Text(
                  summary.journeyAgeLabel!,
                  style: CollectibleTypography.shelfSeriesTitle(
                    textTheme,
                    scheme,
                  ).copyWith(
                    fontSize: 22,
                    letterSpacing: -0.3,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (summary.ipUniversesExplored > 0) ...[
              const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
              _StoryBeat(
                label: CollectorTypeCopy.journeyExploredLabel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.ipUniversesExplored}',
                      style: CollectibleTypography.shelfSeriesTitle(
                        textTheme,
                        scheme,
                      ).copyWith(
                        fontSize: 28,
                        letterSpacing: -0.4,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      summary.ipUniversesExplored == 1
                          ? 'IP universe'
                          : 'IP universes',
                      style: AppTypography.insightsCaption(textTheme, scheme),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StoryBeat extends StatelessWidget {
  const _StoryBeat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.insightsCaption(textTheme, scheme).copyWith(
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}
