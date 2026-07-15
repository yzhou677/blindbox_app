import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/debug/collector_type_mascot_gallery_screen.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_journey_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_evolution_hint_banner.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_ceremony_host.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stale_insights_overlay.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_archived_scope.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared Collection Insights content (no scaffold / app bar).
///
/// Two information kinds share this page:
/// - **Reveal snapshot** ??Collector Type hero + At a Glance / Shelf Progress /
///   Brand Distribution (frozen until the next reveal; muted while stale).
/// - **Live collection history** ??[CollectorJourneyCard] (always current;
///   never part of the reveal snapshot).
class CollectionInsightsBody extends ConsumerWidget {
  const CollectionInsightsBody({super.key});

  static const double _panelGap = FeedRhythm.insightsDashboardToJourney;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEvolutionHint = ref.watch(collectorTypeEvolutionHintProvider);
    final needsReveal = ref.watch(collectorTypeNeedsRevealProvider);
    final stage = ref.watch(collectorTypeViewModelProvider);
    final isRevealed = stage is CollectorTypeRevealRevealed;
    final showStaleBanner = needsReveal && isRevealed;

    return CollectorTypeRevealCeremonyHost(
      child: Column(
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
                if (showStaleBanner) ...[
                  CollectorTypeStaleInsightsOverlay(
                    onRevealAgain: () => ref
                        .read(collectorTypeViewModelProvider.notifier)
                        .requestReveal(),
                    compactMessage: showEvolutionHint,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showEvolutionHint) ...[
                  const CollectorTypeEvolutionHintBanner(),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Reveal snapshot only ??muted while awaiting Reveal again.
                InsightsArchivedScope(
                  archived: showStaleBanner,
                  child: const CollectorTypeRevealCard(),
                ),
                const SizedBox(height: _panelGap),
                // Collector Journey is intentionally LIVE.
                // Unlike Collector Type and other insight cards,
                // Journey reflects the user's evolving collection history
                // and is not part of the Reveal snapshot.
                const CollectorJourneyCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
