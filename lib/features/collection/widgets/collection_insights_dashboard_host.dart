import 'package:blindbox_app/features/collection/application/collection_insights_dashboard_providers.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns dashboard expand/collapse session state so [CollectionScreen] does not
/// rebuild the shelf browse subtree on toggle.
class CollectionInsightsDashboardHost extends ConsumerWidget {
  const CollectionInsightsDashboardHost({
    super.key,
    this.onInsightsTap,
  });

  final VoidCallback? onInsightsTap;

  /// Test-only rebuild counter for search typing perf regression.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(() {
      debugBuildCount++;
      return true;
    }());
    final inputs = ref.watch(collectionInsightsDashboardInputsProvider);
    return CollectionInsightsDashboard(
      stats: inputs.stats,
      shelfMoodLine: inputs.shelfMoodLine,
      memoryWhisper: inputs.memoryWhisper,
      collectorTypeName: inputs.collectorTypeName,
      onInsightsTap: onInsightsTap,
    );
  }
}
