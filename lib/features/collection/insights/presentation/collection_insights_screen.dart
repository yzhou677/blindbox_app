import 'dart:async';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_journey_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_evolution_hint_banner.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/shelf_value_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CollectionInsightsScreen extends ConsumerWidget {
  const CollectionInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEvolutionHint = ref.watch(collectorTypeEvolutionHintProvider);
    final stage = ref.watch(collectorTypeViewModelProvider);
    final textTheme = Theme.of(context).textTheme;

    final showRevealAgain =
        stage is CollectorTypeRevealRevealed ||
        (stage is CollectorTypeRevealIdle && stage.cachedIdentity != null);

    Future<void> exitInsights() async {
      // Route taxonomy boundary:
      // CollectionInsights is a branch-owned page route (not a transient
      // overlay). Its exit path must only perform branch navigation, and must
      // never participate in CollectionModalOverlayRegistry dismissal.
      //
      // Overlay dismissal remains owned by CollectionScreen/MainShell tab
      // switching paths for true PopupRoutes (sheets/dialogs) only.
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        if (context.mounted) context.go('/collection');
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(exitInsights());
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
              titleSpacing: AppSpacing.pageHorizontal,
              title: Text(
                CollectorTypeCopy.screenTitle,
                style: textTheme.titleLarge,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => unawaited(exitInsights()),
              ),
              actions: [
                if (showRevealAgain)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'reveal') {
                        ref
                            .read(collectorTypeViewModelProvider.notifier)
                            .requestReveal();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'reveal',
                        child: Text(CollectorTypeCopy.revealAgain),
                      ),
                    ],
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.belowTabAppBar),
            ),
            const SliverToBoxAdapter(
              child: CollectibleSectionHeader(
                title: CollectorTypeCopy.screenTitle,
                subtitle: CollectorTypeCopy.screenSubtitle,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sm,
                AppSpacing.pageHorizontal,
                FeedRhythm.tabScrollTailPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (showEvolutionHint) ...[
                    CollectorTypeEvolutionHintBanner(
                      onRevealTap: () => ref
                          .read(collectorTypeViewModelProvider.notifier)
                          .requestReveal(),
                    ),
                    const SizedBox(height: FeedRhythm.blockGapMedium),
                  ],
                  const CollectorTypeRevealCard(),
                  const SizedBox(height: FeedRhythm.blockGapMedium),
                  const CollectorJourneyCard(),
                  const SizedBox(height: FeedRhythm.blockGapMedium),
                  const ShelfValueCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
