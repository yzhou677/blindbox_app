import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
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

  static List<CollectionInsightsCompactMetric> metrics(CollectionAggregateStats stats) {
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
    return '${stats.inCollection} ${CollectionVocabulary.figures}, '
        '${stats.completedSeriesCount} ${CollectionVocabulary.completedSeries}, '
        '${stats.masterCompleteSeriesCount} ${CollectionVocabulary.masterComplete}';
  }
}

/// Collapsed achievement summary — morphs between labeled glance and compact glyphs.
class CollectionInsightsCompactSummary extends StatefulWidget {
  const CollectionInsightsCompactSummary({
    super.key,
    required this.stats,
    required this.onTap,
    this.morphOnMount = true,
  });

  final CollectionAggregateStats stats;
  final VoidCallback onTap;

  /// When true, plays labeled → compact morph after the collapsed card appears.
  final bool morphOnMount;

  @override
  State<CollectionInsightsCompactSummary> createState() =>
      CollectionInsightsCompactSummaryState();
}

class CollectionInsightsCompactSummaryState
    extends State<CollectionInsightsCompactSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _morph;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.insightsGlanceMorph,
    );
    _morph = CurvedAnimation(
      parent: _controller,
      curve: CollectibleMotion.easeOut,
      reverseCurve: CollectibleMotion.easeIn,
    );
    if (widget.morphOnMount) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Morph compact glyphs back to labeled glance (before expanding dashboard).
  Future<void> animateToGlance() {
    return _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metrics = CollectionInsightsCompactSummaryFormat.metrics(widget.stats);
    final valueStyle = AppTypography.insightsTotals(textTheme, scheme).copyWith(
      height: 1.0,
      color: scheme.onSurface.withValues(alpha: 0.9),
    );
    final labelStyle = AppTypography.deckText(textTheme, scheme).copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      height: 1.18,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
    );
    final glyphColor = scheme.primary.withValues(alpha: 0.82);

    return Semantics(
      button: true,
      label: CollectionInsightsCompactSummaryFormat.semanticsLabel(widget.stats),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collection_insights_compact_glance'),
          onTap: widget.onTap,
          borderRadius: BorderRadius.vertical(
            top: CollectibleShape.shellRadius.topLeft,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: AnimatedBuilder(
              animation: _morph,
              builder: (context, child) {
                final t = _morph.value;
                return Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: _MorphMetricColumn(
                          metric: metrics[i],
                          compactT: t,
                          valueStyle: valueStyle,
                          labelStyle: labelStyle,
                          glyphColor: glyphColor,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
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

  static const double _glyphSize = 20;

  Widget? _compactGlyph(double t) {
    final size = _glyphSize * t.clamp(0.01, 1.0);
    return switch (metric.kind) {
      CollectionInsightsCompactMetricKind.completedSeries => Icon(
          Icons.check_rounded,
          size: size,
          color: glyphColor,
        ),
      CollectionInsightsCompactMetricKind.masterComplete => Text(
          CollectionInsightsCompactSummaryFormat.masterCompleteGlyph,
          style: TextStyle(fontSize: size, height: 1.0),
        ),
      CollectionInsightsCompactMetricKind.figures => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final labelFactor = (1 - compactT).clamp(0.0, 1.0);
    final glyph = _compactGlyph(compactT);

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
                style: valueStyle,
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
                        child: Text(
                          metric.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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
