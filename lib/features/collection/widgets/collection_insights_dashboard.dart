import 'dart:ui' show lerpDouble;

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';

/// Session-expandable Collection insights block — search stays outside.
abstract final class CollectionInsightsDashboardCopy {
  CollectionInsightsDashboardCopy._();

  static const sectionTitle = 'Collection Insights';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final collapsedBox =
          _collapsedMeasureKey.currentContext?.findRenderObject() as RenderBox?;
      final expandedBox =
          _expandedMeasureKey.currentContext?.findRenderObject() as RenderBox?;
      if (collapsedBox == null ||
          expandedBox == null ||
          !collapsedBox.hasSize ||
          !expandedBox.hasSize) {
        return;
      }
      setState(() {
        _collapsedHeight = collapsedBox.size.height;
        _expandedHeight = expandedBox.size.height;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_collapsedHeight == null || _expandedHeight == null)
          Offstage(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(
                  key: _collapsedMeasureKey,
                  child: _buildCollapsedShell(
                    scheme: scheme,
                    isDark: isDark,
                    compactMorphT: 1,
                    valueStyle: valueStyle,
                    labelStyle: labelStyle,
                    glyphColor: glyphColor,
                  ),
                ),
                KeyedSubtree(
                  key: _expandedMeasureKey,
                  child: _buildExpandedShell(scheme: scheme, expandT: 1),
                ),
              ],
            ),
          ),
        AnimatedBuilder(
          animation: _expand,
          builder: (context, child) {
            final t = _expand.value;
            final compactMorphT = (1 - t).clamp(0.0, 1.0);
            final collapsedShell = _buildCollapsedShell(
              scheme: scheme,
              isDark: isDark,
              compactMorphT: compactMorphT,
              valueStyle: valueStyle,
              labelStyle: labelStyle,
              glyphColor: glyphColor,
            );
            final expandedShell = _buildExpandedShell(
              scheme: scheme,
              expandT: t,
            );

            if (_collapsedHeight != null && _expandedHeight != null) {
              return _buildCrossfadeBody(
                t: t,
                collapsedShell: collapsedShell,
                expandedShell: expandedShell,
              );
            }
            return collapsedShell;
          },
        ),
      ],
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

  Widget _buildCollapsedShell({
    required ColorScheme scheme,
    required bool isDark,
    required double compactMorphT,
    required TextStyle valueStyle,
    required TextStyle labelStyle,
    required Color glyphColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        0,
        AppSpacing.pageHorizontal,
        FeedRhythm.collectionSummaryToShelfHeader,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: CollectibleShape.shellRadius,
          color: scheme.surfaceContainerLow,
          border: Border.all(
            color: Color.lerp(
              scheme.outlineVariant,
              scheme.primary,
              isDark ? 0.12 : 0.18,
            )!,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CollectionInsightsCompactSummary(
              stats: widget.stats,
              onTap: _toggle,
              compactT: compactMorphT,
              valueStyle: valueStyle,
              labelStyle: labelStyle,
              glyphColor: glyphColor,
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.2 : 0.28,
              ),
            ),
            _InsightsDisclosureRow(
              expanded: false,
              chevronTurns: 0,
              onTap: _toggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedShell({
    required ColorScheme scheme,
    required double expandT,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
          ),
          child: _InsightsDisclosureRow(
            expanded: true,
            chevronTurns: 0.5 * expandT.clamp(0.0, 1.0),
            onTap: _toggle,
          ),
        ),
        RepaintBoundary(
          child: CollectionSummarySection(
            stats: widget.stats,
            shelfMoodLine: widget.shelfMoodLine,
            memoryWhisper: widget.memoryWhisper,
            onInsightsTap: widget.onInsightsTap,
            collectorTypeName: widget.collectorTypeName,
          ),
        ),
      ],
    );
  }
}

class _InsightsDisclosureRow extends StatelessWidget {
  const _InsightsDisclosureRow({
    required this.expanded,
    required this.chevronTurns,
    required this.onTap,
  });

  final bool expanded;
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
        borderRadius: expanded
            ? BorderRadius.circular(10)
            : BorderRadius.vertical(
                bottom: CollectibleShape.shellRadius.bottomLeft,
              ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 4 : 14,
            vertical: expanded ? 6 : 11,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: chevronTurns * 3.141592653589793,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  CollectionInsightsDashboardCopy.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.82),
                    letterSpacing: 0.01,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
