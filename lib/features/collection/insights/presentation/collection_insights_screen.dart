import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_evolution_hint_banner.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(CollectorTypeCopy.screenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (stage is CollectorTypeRevealRevealed ||
              (stage is CollectorTypeRevealIdle &&
                  stage.cachedIdentity != null))
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: FeedRhythm.tabScrollTailPadding),
        children: [
          const CollectibleSectionHeader(
            title: CollectorTypeCopy.screenTitle,
            subtitle: CollectorTypeCopy.screenSubtitle,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showEvolutionHint) ...[
                  CollectorTypeEvolutionHintBanner(
                    onRevealTap: () => ref
                        .read(collectorTypeViewModelProvider.notifier)
                        .requestReveal(),
                  ),
                  const SizedBox(height: FeedRhythm.blockGapMedium),
                ],
                const CollectorTypeRevealCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
