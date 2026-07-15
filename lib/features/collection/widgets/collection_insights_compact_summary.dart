import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/collection/presentation/completion_metric_tooltips.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';

/// One achievement column in the collapsed morphing summary.
enum CollectionInsightsCompactMetricKind {
  figures,
  completedSeries,
  masterComplete,
}

@immutable
class CollectionInsightsCompactMetric {
  const CollectionInsightsCompactMetric({
    required this.count,
    required this.label,
    required this.kind,
  });

  final int count;
  final String label;
  final CollectionInsightsCompactMetricKind kind;
}

/// Formatting for the collapsed morphing summary — swap variants here without
/// touching [CollectionInsightsDashboard].
abstract final class CollectionInsightsCompactSummaryFormat {
  CollectionInsightsCompactSummaryFormat._();

  static List<CollectionInsightsCompactMetric> metrics(
    CollectionAggregateStats stats,
  ) {
    return [
      CollectionInsightsCompactMetric(
        count: stats.inCollection,
        label: CollectionSummaryLabels.figures,
        kind: CollectionInsightsCompactMetricKind.figures,
      ),
      CollectionInsightsCompactMetric(
        count: stats.completedSeriesCount,
        label: CollectionSummaryLabels.seriesComplete,
        kind: CollectionInsightsCompactMetricKind.completedSeries,
      ),
      CollectionInsightsCompactMetric(
        count: stats.masterCompleteSeriesCount,
        label: CollectionSummaryLabels.masterComplete,
        kind: CollectionInsightsCompactMetricKind.masterComplete,
      ),
    ];
  }

  /// Compact numeric counts for layout tests (glyphs are separate icons).
  static List<String> compactCounts(CollectionAggregateStats stats) {
    final m = metrics(stats);
    return m.map((e) => '${e.count}').toList();
  }

  /// Compact crown glyph — emoji reads better than icon font at this size.
  static const masterCompleteGlyph = '👑';

  static String semanticsLabel(CollectionAggregateStats stats) {
    return '${stats.inCollection} ${CollectionVocabulary.ownedFigures}, '
        '${stats.completedSeriesCount} ${CollectionVocabulary.completedSeries}, '
        '${stats.masterCompleteSeriesCount} ${CollectionVocabulary.masterComplete}';
  }
}

/// Collapsed achievement summary — morph progress driven by parent animation.
class CollectionInsightsCompactSummary extends StatelessWidget {
  const CollectionInsightsCompactSummary({
    super.key,
    required this.stats,
    this.onTap,
    required this.compactT,
    required this.valueStyle,
    required this.labelStyle,
    required this.glyphColor,
  });

  final CollectionAggregateStats stats;
  final VoidCallback? onTap;

  /// `0` = labeled glance, `1` = compact glyphs.
  final double compactT;
  final TextStyle valueStyle;
  final TextStyle labelStyle;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) {
    final metrics = CollectionInsightsCompactSummaryFormat.metrics(stats);
    final row = Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: _MorphMetricColumn(
              metric: metrics[i],
              compactT: compactT,
              valueStyle: valueStyle,
              labelStyle: labelStyle,
              glyphColor: glyphColor,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: onTap != null,
      label: CollectionInsightsCompactSummaryFormat.semanticsLabel(stats),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collection_insights_compact_glance'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: row,
          ),
        ),
      ),
    );
  }
}

class _MorphMetricColumn extends StatelessWidget {
  const _MorphMetricColumn({
    required this.metric,
    required this.compactT,
    required this.valueStyle,
    required this.labelStyle,
    required this.glyphColor,
  });

  final CollectionInsightsCompactMetric metric;
  final double compactT;
  final TextStyle valueStyle;
  final TextStyle labelStyle;
  final Color glyphColor;

  static const double _glyphSize = 22;

  bool get _muted {
    return switch (metric.kind) {
      CollectionInsightsCompactMetricKind.figures => false,
      CollectionInsightsCompactMetricKind.completedSeries ||
      CollectionInsightsCompactMetricKind.masterComplete => metric.count == 0,
    };
  }

  /// Matches expanded [_ShelfGlanceStatCell] muted count alpha (0.36).
  Color _mutedCountColor(ColorScheme scheme) =>
      scheme.onSurface.withValues(alpha: 0.36);

  TextStyle _effectiveValueStyle(BuildContext context) {
    if (!_muted) return valueStyle;
    return valueStyle.copyWith(
      color: _mutedCountColor(Theme.of(context).colorScheme),
    );
  }

  Widget? _compactGlyph(double t, ColorScheme scheme) {
    final size = _glyphSize * t.clamp(0.01, 1.0);
    final color = _muted ? _mutedCountColor(scheme) : glyphColor;
    return switch (metric.kind) {
      CollectionInsightsCompactMetricKind.completedSeries => Icon(
        Icons.check_rounded,
        size: size,
        color: color,
      ),
      CollectionInsightsCompactMetricKind.masterComplete => Opacity(
        opacity: _muted ? 0.36 : 1,
        child: Text(
          CollectionInsightsCompactSummaryFormat.masterCompleteGlyph,
          style: TextStyle(fontSize: size, height: 1.0),
        ),
      ),
      CollectionInsightsCompactMetricKind.figures => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelFactor = (1 - compactT).clamp(0.0, 1.0);
    final glyph = _compactGlyph(compactT, scheme);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (glyph != null && compactT > 0.001) ...[
                glyph,
                SizedBox(width: 3 * compactT),
              ],
              Text(
                '${metric.count}',
                textAlign: TextAlign.center,
                style: _effectiveValueStyle(context),
              ),
            ],
          ),
          if (labelFactor > 0.001)
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: labelFactor,
                child: Opacity(
                  opacity: labelFactor,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 96,
                      height: FeedRhythm.collectionSummaryLabelHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _MetricLabelText(
                          metric: metric,
                          style: labelStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricLabelText extends StatelessWidget {
  const _MetricLabelText({required this.metric, required this.style});

  final CollectionInsightsCompactMetric metric;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      metric.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );
    if (metric.kind != CollectionInsightsCompactMetricKind.completedSeries) {
      return text;
    }
    return Tooltip(
      message: CompletionMetricTooltips.completedSeries,
      child: text,
    );
  }
}
