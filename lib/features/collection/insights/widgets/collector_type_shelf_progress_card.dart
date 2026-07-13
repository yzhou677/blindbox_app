import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_dashboard_panel.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:flutter/material.dart';

/// Presentation helpers for Shelf Progress — no new completion math.
abstract final class ShelfProgressPresentation {
  ShelfProgressPresentation._();

  /// Master Completion appears only after the first Master Complete series.
  static bool showMasterCompletion(CollectorTypeStats stats) =>
      stats.masterCompleteSeriesCount > 0;

  /// Share of Master-eligible (Secret-bearing) series that are Master Complete.
  static double masterCompletionRatio(CollectorTypeStats stats) {
    final eligible = stats.masterEligibleSeriesCount;
    if (eligible <= 0) return 0;
    return (stats.masterCompleteSeriesCount / eligible).clamp(0.0, 1.0);
  }

  static int masterCompletionPercent(CollectorTypeStats stats) =>
      (masterCompletionRatio(stats) * 100).round().clamp(0, 100);
}

/// Dedicated shelf completion surface — presentation of existing reveal stats.
///
/// Progressive disclosure: Regular Progress always; Master Completion only
/// once [CollectorTypeStats.masterCompleteSeriesCount] is at least one.
class CollectorTypeShelfProgressCard extends StatelessWidget {
  const CollectorTypeShelfProgressCard({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final regularRatio = (stats.completionPercent / 100).clamp(0.0, 1.0);
    final showMaster = ShelfProgressPresentation.showMasterCompletion(stats);

    return InsightsDashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shelf Progress',
            style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          _ProgressRow(
            label: CollectionVocabulary.regularProgress,
            valueText: '${stats.completionPercent}%',
            ratio: regularRatio,
            primary: true,
            scheme: scheme,
            textTheme: textTheme,
          ),
          if (showMaster) ...[
            const SizedBox(height: AppSpacing.lg),
            _ProgressRow(
              label: CollectionVocabulary.masterCompletion,
              leadingGlyph: CollectionInsightsCompactSummaryFormat
                  .masterCompleteGlyph,
              valueText:
                  '${ShelfProgressPresentation.masterCompletionPercent(stats)}%',
              ratio: ShelfProgressPresentation.masterCompletionRatio(stats),
              primary: false,
              scheme: scheme,
              textTheme: textTheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.valueText,
    required this.ratio,
    required this.primary,
    required this.scheme,
    required this.textTheme,
    this.leadingGlyph,
  });

  final String label;
  final String valueText;
  final double ratio;
  final bool primary;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final String? leadingGlyph;

  @override
  Widget build(BuildContext context) {
    final labelStyle = primary
        ? CollectibleTypography.shelfProgressLine(textTheme, scheme).copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.82),
          )
        : CollectibleTypography.shelfMasterCompleteStatLine(textTheme, scheme)
            .copyWith(
            fontWeight: FontWeight.w500,
            fontSize: (textTheme.bodyMedium?.fontSize ?? 14) - 0.5,
            color: Color.lerp(
              scheme.onSurfaceVariant,
              const Color(0xFFC9A227),
              0.42,
            )!.withValues(alpha: 0.78),
          );

    final valueStyle = primary
        ? textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: scheme.onSurface.withValues(alpha: 0.88),
          )
        : textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          );

    final barHeight = primary ? 5.0 : 3.5;
    final barColor = primary
        ? scheme.primary.withValues(alpha: 0.48)
        : Color.lerp(
            scheme.primary,
            const Color(0xFFC9A227),
            0.55,
          )!.withValues(alpha: 0.38);
    final trackColor = scheme.surfaceContainerHighest.withValues(
      alpha: primary ? 0.34 : 0.26,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (leadingGlyph != null) ...[
              Text(
                leadingGlyph!,
                style: TextStyle(
                  fontSize: primary ? 14 : 12,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(valueText, style: valueStyle),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: barHeight,
            backgroundColor: trackColor,
            color: barColor,
          ),
        ),
      ],
    );
  }
}
