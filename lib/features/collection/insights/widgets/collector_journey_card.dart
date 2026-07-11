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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg + 2,
        AppSpacing.pageHorizontal,
        AppSpacing.lg + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CollectorTypeCopy.journeyTitle,
            style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
          ),
          const SizedBox(height: 6),
          Text(
            CollectorTypeCopy.journeySubtitle,
            style: AppTypography.insightsFlavor(textTheme, scheme).copyWith(
              fontSize: 13,
              height: 1.35,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
            ),
          ),
          if (!summary.hasHistory) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              CollectorTypeCopy.journeyEmpty,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            // Group Started + Explored as related story beats.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.journeyAgeLabel != null)
                  Expanded(
                    child: _StoryBeat(
                      label: CollectorTypeCopy.journeyStartedLabel,
                      child: Text(
                        summary.journeyAgeLabel!,
                        style: CollectibleTypography.shelfSeriesTitle(
                          textTheme,
                          scheme,
                        ).copyWith(
                          fontSize: 18,
                          letterSpacing: -0.25,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (summary.journeyAgeLabel != null &&
                    summary.ipUniversesExplored > 0)
                  const SizedBox(width: AppSpacing.lg),
                if (summary.ipUniversesExplored > 0)
                  Expanded(
                    child: _StoryBeat(
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
                              fontSize: 22,
                              letterSpacing: -0.35,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary.ipUniversesExplored == 1
                                ? 'IP universe'
                                : 'IP universes',
                            style: AppTypography.insightsCaption(
                              textTheme,
                              scheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
            letterSpacing: 0.35,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
