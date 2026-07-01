import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
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
    required this.expanded,
    required this.onExpandedChanged,
    required this.stats,
    this.shelfMoodLine,
    this.memoryWhisper,
    this.onInsightsTap,
    this.collectorTypeName,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final VoidCallback? onInsightsTap;
  final String? collectorTypeName;

  @override
  State<CollectionInsightsDashboard> createState() =>
      _CollectionInsightsDashboardState();
}

class _CollectionInsightsDashboardState extends State<CollectionInsightsDashboard> {
  final _morphKey = GlobalKey<CollectionInsightsCompactSummaryState>();

  Future<void> _toggle() async {
    if (widget.expanded) {
      widget.onExpandedChanged(false);
      return;
    }

    final morph = _morphKey.currentState;
    if (morph != null) {
      await morph.animateToGlance();
    }
    if (!mounted) return;
    widget.onExpandedChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSize(
      duration: CollectibleMotion.sectionReveal,
      curve: CollectibleMotion.easeOut,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: widget.expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                  ),
                  child: _InsightsDisclosureRow(
                    expanded: true,
                    onTap: _toggle,
                  ),
                ),
                CollectionSummarySection(
                  stats: widget.stats,
                  shelfMoodLine: widget.shelfMoodLine,
                  memoryWhisper: widget.memoryWhisper,
                  onInsightsTap: widget.onInsightsTap,
                  collectorTypeName: widget.collectorTypeName,
                ),
              ],
            )
          : Padding(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CollectionInsightsCompactSummary(
                      key: _morphKey,
                      stats: widget.stats,
                      onTap: _toggle,
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
                      onTap: _toggle,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InsightsDisclosureRow extends StatelessWidget {
  const _InsightsDisclosureRow({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
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
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: CollectibleMotion.sectionReveal,
                curve: CollectibleMotion.easeOut,
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
