import 'dart:ui' show lerpDouble;

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';

/// Session-expandable Collection insights block — search stays outside.
abstract final class CollectionInsightsDashboardCopy {
  CollectionInsightsDashboardCopy._();

  static const sectionTitle = 'Collection Insights';
  static const summaryHeader = 'Summary';
}

class CollectionInsightsDashboard extends StatefulWidget {
  const CollectionInsightsDashboard({
    super.key,
    required this.stats,
    this.shelfMoodLine,
    this.memoryWhisper,
    this.onInsightsTap,
    this.collectorTypeName,
  });

  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final VoidCallback? onInsightsTap;
  final String? collectorTypeName;

  @override
  State<CollectionInsightsDashboard> createState() =>
      _CollectionInsightsDashboardState();
}

class _CollectionInsightsDashboardState extends State<CollectionInsightsDashboard>
    with SingleTickerProviderStateMixin {
  final _collapsedMeasureKey = GlobalKey();
  final _expandedMeasureKey = GlobalKey();

  late final AnimationController _expandController;
  late final Animation<double> _expand;

  double? _collapsedHeight;
  double? _expandedHeight;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: CollectibleMotion.insightsDashboardTransition,
    );
    _expand = CurvedAnimation(
      parent: _expandController,
      curve: CollectibleMotion.easeOut,
      reverseCurve: CollectibleMotion.easeIn,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CollectionInsightsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_collapsedLayoutInputsChanged(oldWidget, widget)) {
      _collapsedHeight = null;
    }
    if (_expandedLayoutInputsChanged(oldWidget, widget)) {
      _expandedHeight = null;
    }
  }

  static bool _statsChanged(
    CollectionAggregateStats a,
    CollectionAggregateStats b,
  ) {
    return a.inCollection != b.inCollection ||
        a.wantListCount != b.wantListCount ||
        a.completedSeriesCount != b.completedSeriesCount ||
        a.masterCompleteSeriesCount != b.masterCompleteSeriesCount;
  }

  static bool _collapsedLayoutInputsChanged(
    CollectionInsightsDashboard oldWidget,
    CollectionInsightsDashboard widget,
  ) {
    return _statsChanged(oldWidget.stats, widget.stats);
  }

  static bool _expandedLayoutInputsChanged(
    CollectionInsightsDashboard oldWidget,
    CollectionInsightsDashboard widget,
  ) {
    return _statsChanged(oldWidget.stats, widget.stats) ||
        oldWidget.shelfMoodLine != widget.shelfMoodLine ||
        oldWidget.memoryWhisper != widget.memoryWhisper ||
        oldWidget.collectorTypeName != widget.collectorTypeName ||
        (oldWidget.onInsightsTap == null) !=
            (widget.onInsightsTap == null);
  }

  void _toggle() {
    if (_expandController.isAnimating) return;
    if (_expandController.value >= 1.0) {
      _expandController.reverse();
    } else {
      _expandController.forward();
    }
  }

  void _scheduleMeasure() {
    if (_collapsedHeight != null && _expandedHeight != null) return;
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(_commitMeasure);
  }

  void _commitMeasure(Duration _) {
    _measureScheduled = false;
    if (!mounted) return;
    if (_collapsedHeight != null && _expandedHeight != null) return;

    double? collapsed;
    double? expanded;

    if (_collapsedHeight == null) {
      final collapsedBox =
          _collapsedMeasureKey.currentContext?.findRenderObject() as RenderBox?;
      if (collapsedBox != null && collapsedBox.hasSize) {
        collapsed = collapsedBox.size.height;
      }
    }
    if (_expandedHeight == null) {
      final expandedBox =
          _expandedMeasureKey.currentContext?.findRenderObject() as RenderBox?;
      if (expandedBox != null && expandedBox.hasSize) {
        expanded = expandedBox.size.height;
      }
    }

    if (collapsed == null && expanded == null) return;

    setState(() {
      if (collapsed != null) _collapsedHeight = collapsed;
      if (expanded != null) _expandedHeight = expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final valueStyle = AppTypography.insightsTotals(textTheme, scheme).copyWith(
      fontSize: 26,
      height: 1.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: scheme.onSurface.withValues(alpha: 0.96),
    );
    final labelStyle = AppTypography.deckText(textTheme, scheme).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.18,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
    );
    final glyphColor = scheme.primary.withValues(alpha: 0.88);

    return AnimatedBuilder(
      animation: _expand,
      builder: (context, child) {
        final t = _expand.value;
        final compactMorphT = (1 - t).clamp(0.0, 1.0);
        final collapsedShell = _buildCollapsedCard(
          scheme: scheme,
          isDark: isDark,
          compactMorphT: compactMorphT,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
          glyphColor: glyphColor,
        );
        final expandedShell = _buildExpandedCard();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_collapsedHeight == null || _expandedHeight == null)
              Offstage(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KeyedSubtree(
                      key: _collapsedMeasureKey,
                      child: collapsedShell,
                    ),
                    KeyedSubtree(
                      key: _expandedMeasureKey,
                      child: expandedShell,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
              ),
              child: _SummaryHeaderRow(
                chevronTurns: 0.5 * t.clamp(0.0, 1.0),
                onTap: _toggle,
              ),
            ),
            const SizedBox(height: FeedRhythm.collectionSummaryHeaderToCard),
            if (_collapsedHeight != null && _expandedHeight != null)
              _buildCrossfadeBody(
                t: t,
                collapsedShell: collapsedShell,
                expandedShell: expandedShell,
              )
            else if (_collapsedHeight != null &&
                _expandedHeight == null &&
                t > 0)
              expandedShell
            else if (_collapsedHeight != null && t == 0)
              SizedBox(
                height: _collapsedHeight,
                width: double.infinity,
                child: ClipRect(child: collapsedShell),
              )
            else
              collapsedShell,
          ],
        );
      },
    );
  }

  /// Clips a layer to [height] without [RenderFlex] overflow during lerp.
  Widget _clipAnimatedLayer({
    required double height,
    required Widget child,
  }) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: 1,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildCrossfadeBody({
    required double t,
    required Widget collapsedShell,
    required Widget expandedShell,
  }) {
    final height = lerpDouble(_collapsedHeight!, _expandedHeight!, t)!;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            if (t < 1)
              Positioned.fill(
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: RepaintBoundary(
                    child: _clipAnimatedLayer(
                      height: height,
                      child: collapsedShell,
                    ),
                  ),
                ),
              ),
            if (t > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: RepaintBoundary(
                    child: _clipAnimatedLayer(
                      height: height,
                      child: expandedShell,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedCard({
    required ColorScheme scheme,
    required bool isDark,
    required double compactMorphT,
    required TextStyle valueStyle,
    required TextStyle labelStyle,
    required Color glyphColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: scheme.surfaceContainerLow.withValues(
                alpha: isDark ? 0.62 : 0.88,
              ),
              border: Border.all(
                width: 0.8,
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.24 : 0.34,
                ),
              ),
            ),
            child: CollectionInsightsCompactSummary(
              stats: widget.stats,
              onTap: _toggle,
              compactT: compactMorphT,
              valueStyle: valueStyle,
              labelStyle: labelStyle,
              glyphColor: glyphColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCard() {
    return RepaintBoundary(
      child: CollectionSummarySection(
        stats: widget.stats,
        shelfMoodLine: widget.shelfMoodLine,
        memoryWhisper: widget.memoryWhisper,
        onInsightsTap: widget.onInsightsTap,
        collectorTypeName: widget.collectorTypeName,
      ),
    );
  }
}

/// Persistent expand/collapse affordance above the summary card.
class _SummaryHeaderRow extends StatelessWidget {
  const _SummaryHeaderRow({
    required this.chevronTurns,
    required this.onTap,
  });

  final double chevronTurns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('collection_insights_dashboard_toggle'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  CollectionInsightsDashboardCopy.summaryHeader,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.88),
                    letterSpacing: 0.05,
                  ),
                ),
              ),
              Transform.rotate(
                angle: chevronTurns * 3.141592653589793,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
