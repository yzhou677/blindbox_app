import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_dashboard_panel.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';

/// Dedicated shelf completion surface — presentation of existing reveal stats.
class CollectorTypeShelfProgressCard extends StatelessWidget {
  const CollectorTypeShelfProgressCard({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratio = (stats.completionPercent / 100).clamp(0.0, 1.0);

    return InsightsDashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shelf Progress',
            style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 5.5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.38),
                        color: scheme.primary.withValues(alpha: 0.58),
                      ),
                    ),
                    Text(
                      '${stats.completionPercent}%',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.35,
                        height: 1,
                        color: scheme.onSurface.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4.5,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.32),
                        color: scheme.primary.withValues(alpha: 0.42),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md + 2),
                    Text(
                      '${stats.trackedSeries} ${CollectionVocabulary.series}',
                      style: CollectibleTypography.shelfProgressLine(
                        textTheme,
                        scheme,
                      ).copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
