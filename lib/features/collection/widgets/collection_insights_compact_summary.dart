import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';

/// Formatting for the collapsed numeric glance — swap variants here without
/// touching [CollectionInsightsDashboard].
abstract final class CollectionInsightsCompactSummaryFormat {
  CollectionInsightsCompactSummaryFormat._();

  static String figures(int count) => '$count';

  static String completedSeries(int count) => '✓$count';

  static String masterComplete(int count) => '👑$count';

  /// Screen-reader label when visible copy is numeric only.
  static String semanticsLabel(CollectionAggregateStats stats) {
    return '${stats.inCollection} ${CollectionVocabulary.figures}, '
        '${stats.completedSeriesCount} ${CollectionVocabulary.completedSeries}, '
        '${stats.masterCompleteSeriesCount} ${CollectionVocabulary.masterComplete}';
  }

  /// Visible cell values left-to-right (figures, completed series, master).
  static List<String> cells(CollectionAggregateStats stats) {
    return [
      figures(stats.inCollection),
      completedSeries(stats.completedSeriesCount),
      masterComplete(stats.masterCompleteSeriesCount),
    ];
  }
}

/// Collapsed achievement summary — numeric triptych; labels live in expanded view.
class CollectionInsightsCompactSummary extends StatelessWidget {
  const CollectionInsightsCompactSummary({
    super.key,
    required this.stats,
    required this.onTap,
  });

  final CollectionAggregateStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final values = CollectionInsightsCompactSummaryFormat.cells(stats);
    final valueStyle = AppTypography.insightsTotals(textTheme, scheme).copyWith(
      height: 1.0,
      color: scheme.onSurface.withValues(alpha: 0.9),
    );

    return Semantics(
      button: true,
      label: CollectionInsightsCompactSummaryFormat.semanticsLabel(stats),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collection_insights_compact_glance'),
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: CollectibleShape.shellRadius.topLeft,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _NumericCell(
                    value: values[0],
                    style: valueStyle,
                  ),
                ),
                Expanded(
                  child: _NumericCell(
                    value: values[1],
                    style: valueStyle,
                  ),
                ),
                Expanded(
                  child: _NumericCell(
                    value: values[2],
                    style: valueStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumericCell extends StatelessWidget {
  const _NumericCell({
    required this.value,
    required this.style,
  });

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}
