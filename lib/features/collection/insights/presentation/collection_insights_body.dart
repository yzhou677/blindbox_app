import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/debug/collector_type_mascot_gallery_screen.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_journey_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_evolution_hint_banner.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared Collection Insights content (no scaffold / app bar).
///
/// Used by [CollectionInsightsScreen] (route) and the Collection page Insights
/// segment — same cards and copy, presentation-only reuse.
class CollectionInsightsBody extends ConsumerWidget {
  const CollectionInsightsBody({super.key});

  static const double _panelGap = FeedRhythm.insightsDashboardToJourney;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEvolutionHint = ref.watch(collectorTypeEvolutionHintProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onLongPress: kDebugMode
              ? () => context.push(CollectorTypeMascotGalleryScreen.routePath)
              : null,
          behavior: HitTestBehavior.opaque,
          child: const CollectibleSectionHeader(
            title: CollectorTypeCopy.screenTitle,
            subtitle: CollectorTypeCopy.screenSubtitle,
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            FeedRhythm.tabScrollTailPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showEvolutionHint) ...[
                const CollectorTypeEvolutionHintBanner(),
                const SizedBox(height: _panelGap),
              ],
              const CollectorTypeRevealCard(),
              const SizedBox(height: _panelGap),
              const CollectorJourneyCard(),
            ],
          ),
        ),
      ],
    );
  }
}
