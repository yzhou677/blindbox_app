import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_ambient_glow.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_analyzing_panel.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_button.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_result_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stats_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectorTypeRevealCard extends ConsumerWidget {
  const CollectorTypeRevealCard({super.key});

  double _intensityForStage(CollectorTypeRevealStage stage) {
    if (stage is CollectorTypeRevealAnalyzing) return 0.5;
    return 1.0;
  }

  bool _shouldAnimateGlow(CollectorTypeRevealStage stage) {
    // Keep the card calm during analyzing where there is already an active
    // progress animation (pulsing dots). This reduces concurrent ticker load.
    return stage is! CollectorTypeRevealAnalyzing;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(collectorTypeViewModelProvider);
    final brightness = Theme.of(context).brightness;
    final accent = switch (stage) {
      CollectorTypeRevealRevealed(:final identity) =>
        identity.archetype.accentFor(brightness),
      CollectorTypeRevealIdle(:final cachedIdentity) =>
        cachedIdentity?.archetype.accentFor(brightness),
      _ => null,
    };

    return CollectorTypeAmbientGlow(
      accent: accent,
      intensity: _intensityForStage(stage),
      animate: _shouldAnimateGlow(stage),
      child: AnimatedSwitcher(
        duration: CollectibleMotion.sectionReveal,
        switchInCurve: CollectibleMotion.easeOut,
        switchOutCurve: CollectibleMotion.easeIn,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: CollectibleMotion.easeOut,
            reverseCurve: CollectibleMotion.easeIn,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              child: child,
            ),
          );
        },
        child: switch (stage) {
          CollectorTypeRevealIdle(:final cachedIdentity) => _IdleStage(
              key: const ValueKey('idle'),
              cachedIdentity: cachedIdentity,
              onReveal: () => ref
                  .read(collectorTypeViewModelProvider.notifier)
                  .requestReveal(),
            ),
          CollectorTypeRevealAnalyzing() => const CollectorTypeAnalyzingPanel(
              key: ValueKey('analyzing'),
            ),
          CollectorTypeRevealRevealed(:final identity) => _RevealedStage(
              key: ValueKey('revealed-${identity.archetypeId.name}'),
              identity: identity,
            ),
        },
      ),
    );
  }
}

class _IdleStage extends StatelessWidget {
  const _IdleStage({
    super.key,
    required this.cachedIdentity,
    required this.onReveal,
  });

  final CollectorTypeIdentity? cachedIdentity;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final cached = cachedIdentity;
    if (cached != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollectorTypeResultCard(identity: cached),
          const SizedBox(height: 12),
          CollectorTypeRevealButton(
            label: CollectorTypeCopy.revealAgain,
            onPressed: onReveal,
          ),
        ],
      );
    }
    return CollectorTypeRevealButton(onPressed: onReveal);
  }
}

class _RevealedStage extends StatelessWidget {
  const _RevealedStage({super.key, required this.identity});

  final CollectorTypeIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectorTypeResultCard(identity: identity),
        CollectorTypeStatsStrip(stats: identity.stats),
      ],
    );
  }
}
