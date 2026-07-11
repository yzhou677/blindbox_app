import 'dart:async';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_body.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CollectionInsightsScreen extends ConsumerWidget {
  const CollectionInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsReveal = ref.watch(collectorTypeNeedsRevealProvider);
    final stage = ref.watch(collectorTypeViewModelProvider);
    final textTheme = Theme.of(context).textTheme;

    final showRevealAgainMenu =
        stage is CollectorTypeRevealRevealed && !needsReveal;

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
                if (showRevealAgainMenu)
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
            const SliverToBoxAdapter(child: CollectionInsightsBody()),
          ],
        ),
      ),
    );
  }
}
