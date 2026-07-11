import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_journey_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_evolution_hint_banner.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared Collection Insights content (no scaffold / app bar).
///
/// Used by [CollectionInsightsScreen] (route) and the Collection page Insights
/// segment — same cards and copy, presentation-only reuse.
class CollectionInsightsBody extends ConsumerWidget {
  const CollectionInsightsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEvolutionHint = ref.watch(collectorTypeEvolutionHintProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CollectibleSectionHeader(
          title: CollectorTypeCopy.screenTitle,
          subtitle: CollectorTypeCopy.screenSubtitle,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
            AppSpacing.pageHorizontal,
            FeedRhythm.tabScrollTailPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showEvolutionHint) ...[
                const CollectorTypeEvolutionHintBanner(),
                const SizedBox(height: FeedRhythm.blockGapMedium),
              ],
              const CollectorTypeRevealCard(),
              const SizedBox(height: FeedRhythm.blockGapMedium),
              const CollectorJourneyCard(),
            ],
          ),
        ),
      ],
    );
  }
}
