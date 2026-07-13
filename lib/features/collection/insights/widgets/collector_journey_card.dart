import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_dashboard_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Story card for how the shelf has unfolded — narrative rhythm, not key-value rows.
///
/// Collector Journey is intentionally LIVE.
/// Unlike Collector Type and other insight cards,
/// Journey reflects the user's evolving collection history
/// and is not part of the Reveal snapshot.
///
/// ## Diary growth
///
/// Keep Journey lightweight. Started + Explored stay as stable slots.
/// Latest Memory is optional — omit when memory has no moment yet.
/// Prefer memorable moments over additional counters; never grow into a dashboard.
class CollectorJourneyCard extends ConsumerWidget {
  const CollectorJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(collectorJourneySummaryProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final startedValue =
        summary.journeyAgeLabel ?? CollectorTypeCopy.journeyStartedPending;
    final exploredCount = summary.ipUniversesExplored;
    final memory = summary.latestMemory;

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
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StoryBeat(
                  label: CollectorTypeCopy.journeyStartedLabel,
                  child: Text(
                    startedValue,
                    style: CollectibleTypography.shelfSeriesTitle(
                      textTheme,
                      scheme,
                    ).copyWith(
                      fontSize: 18,
                      letterSpacing: -0.25,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: summary.journeyAgeLabel == null
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _StoryBeat(
                  label: CollectorTypeCopy.journeyExploredLabel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$exploredCount',
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
                        exploredCount == 1 ? 'IP universe' : 'IP universes',
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
          if (memory != null) ...[
            const SizedBox(height: AppSpacing.lg + 2),
            _LatestMemoryBeat(memory: memory),
          ],
        ],
      ),
    );
  }
}

class _LatestMemoryBeat extends StatelessWidget {
  const _LatestMemoryBeat({required this.memory});

  final JourneyLatestMemory memory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = switch (memory.kind) {
      JourneyMemoryKind.masterComplete =>
        CollectorTypeCopy.journeyMemoryMasterComplete,
      JourneyMemoryKind.completedSeries =>
        CollectorTypeCopy.journeyMemoryCompleted,
      JourneyMemoryKind.firstSecret =>
        CollectorTypeCopy.journeyMemoryFirstSecret,
    };
    final seriesName = memory.seriesName?.trim();

    return _StoryBeat(
      label: CollectorTypeCopy.journeyLatestMemoryLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CollectibleTypography.shelfSeriesTitle(
              textTheme,
              scheme,
            ).copyWith(
              fontSize: 17,
              letterSpacing: -0.2,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (seriesName != null && seriesName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              seriesName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.insightsFlavor(textTheme, scheme).copyWith(
                fontSize: 14,
                height: 1.3,
                color: scheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            memory.ageLabel,
            style: AppTypography.insightsCaption(textTheme, scheme).copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
            ),
          ),
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
