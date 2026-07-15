import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/collector_type_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_explainability.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_ambient_glow.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_analyzing_panel.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_button.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_result_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stats_strip.dart';
import 'package:blindbox_app/features/sharing/presentation/share_card_preview.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
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
    final snapshot = ref.watch(collectionNotifierProvider);
    final journey = ref.watch(collectorJourneySummaryProvider);
    final brightness = Theme.of(context).brightness;
    final helperLine = switch (stage) {
      CollectorTypeRevealRevealed(:final identity) =>
        resolveCollectorTypeHelperLine(
          identity: identity,
          journey: journey,
          snapshot: snapshot,
        ),
      _ => null,
    };
    final accent = switch (stage) {
      CollectorTypeRevealRevealed(:final identity) =>
        identity.archetype.accentFor(brightness),
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
          CollectorTypeRevealIdle() => _IdleStage(
            key: const ValueKey('idle'),
            onReveal: () => ref
                .read(collectorTypeViewModelProvider.notifier)
                .requestReveal(),
          ),
          CollectorTypeRevealAnalyzing() => const CollectorTypeAnalyzingPanel(
            key: ValueKey('analyzing'),
          ),
          CollectorTypeRevealRevealed(:final identity) => _RevealedStage(
            key: ValueKey('revealed-${identity.archetypeId.name}'),
            identity: identity.healed(),
            helperLine: helperLine,
          ),
        },
      ),
    );
  }
}

class _IdleStage extends StatelessWidget {
  const _IdleStage({super.key, required this.onReveal});

  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return CollectorTypeRevealButton(onPressed: onReveal);
  }
}

/// Persistent Insights hero + dashboard — stale treatment lives in the body.
class _RevealedStage extends ConsumerWidget {
  const _RevealedStage({
    super.key,
    required this.identity,
    required this.helperLine,
  });

  final CollectorTypeIdentity identity;
  final String? helperLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayStats =
        ref.watch(collectorTypeDisplayStatsProvider) ?? identity.stats;
    final payload = buildCollectorTypeSharePayload(
      identity,
      brightness: Theme.of(context).brightness,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectorTypeResultCard(
          identity: identity,
          helperLine: helperLine,
          onShare: payload == null
              ? null
              : () => showShareCardPreview(
                  context: context,
                  card: CollectorTypeShareCard(payload: payload),
                  basename: 'shelfy-identity-card',
                  loadingLabel: 'Preparing your Collector Card...',
                  previewTitle: 'Collector Card',
                ),
        ),
        CollectorTypeStatsStrip(stats: displayStats),
      ],
    );
  }
}
