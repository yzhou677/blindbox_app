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
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 8,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        color: scheme.primary.withValues(alpha: 0.78),
                      ),
                    ),
                    Text(
                      '${stats.completionPercent}%',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1,
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
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        color: scheme.primary.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${stats.trackedSeries} ${CollectionVocabulary.series}',
                      style: CollectibleTypography.shelfProgressLine(
                        textTheme,
                        scheme,
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
