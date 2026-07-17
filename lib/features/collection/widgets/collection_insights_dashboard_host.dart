import 'package:blindbox_app/features/collection/application/collection_insights_dashboard_providers.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns dashboard expand/collapse session state so [CollectionScreen] does not
/// rebuild the shelf browse subtree on toggle.
class CollectionInsightsDashboardHost extends ConsumerWidget {
  const CollectionInsightsDashboardHost({
    super.key,
    this.onInsightsTap,
    this.statsOverride,
    this.shelfMoodLineOverride,
    this.memoryWhisperOverride,
    this.collectorTypeNameOverride,
    this.metricLabels = CollectionSummaryMetricLabels.collection,
    this.expandable = true,
    this.summaryCardVerticalPadding =
        FeedRhythm.collectionSummaryCardVerticalPadding,
    this.summaryCardTopPadding,
    this.summaryCardBottomPadding,
  });

  final VoidCallback? onInsightsTap;
  final CollectionAggregateStats? statsOverride;
  final String? shelfMoodLineOverride;
  final String? memoryWhisperOverride;
  final String? collectorTypeNameOverride;
  final CollectionSummaryMetricLabels metricLabels;
  final bool expandable;
  final double summaryCardVerticalPadding;
  final double? summaryCardTopPadding;
  final double? summaryCardBottomPadding;

  /// Test-only rebuild counter for search typing perf regression.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(() {
      debugBuildCount++;
      return true;
    }());
    final usesOverride = statsOverride != null;
    final inputs = usesOverride
        ? null
        : ref.watch(collectionInsightsDashboardInputsProvider);
    return CollectionInsightsDashboard(
      stats: statsOverride ?? inputs!.stats,
      shelfMoodLine: usesOverride
          ? shelfMoodLineOverride
          : inputs!.shelfMoodLine,
      memoryWhisper: usesOverride
          ? memoryWhisperOverride
          : inputs!.memoryWhisper,
      collectorTypeName: usesOverride
          ? collectorTypeNameOverride
          : inputs!.collectorTypeName,
      onInsightsTap: onInsightsTap,
      metricLabels: metricLabels,
      expandable: expandable,
      summaryCardVerticalPadding: summaryCardVerticalPadding,
      summaryCardTopPadding: summaryCardTopPadding,
      summaryCardBottomPadding: summaryCardBottomPadding,
    );
  }
}
