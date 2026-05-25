import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:flutter/material.dart';

/// At most one calm chip for aggregated collectible activity.
class CollectibleMarketSignals extends StatelessWidget {
  const CollectibleMarketSignals({super.key, required this.snapshot});

  final CollectibleMarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = _chipLabel();
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String? _chipLabel() {
    if (snapshot.rarityPresence == RarityPresence.observed) return 'Secret';
    if (snapshot.marketMood == MarketMood.active) return 'Recently active';
    return null;
  }
}
