import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_button.dart';
import 'package:flutter/material.dart';

/// De-emphasis applied to the previous-analysis dashboard while stale.
const double collectorTypeStaleInsightsOpacity = 0.72;

/// Non-blocking stale-analysis card — explains prior insights and offers re-reveal.
class CollectorTypeStaleInsightsOverlay extends StatelessWidget {
  const CollectorTypeStaleInsightsOverlay({
    super.key,
    required this.onRevealAgain,
    this.compactMessage = false,
  });

  final VoidCallback onRevealAgain;
  final bool compactMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message = compactMessage
        ? CollectorTypeCopy.staleInsightsMessageCompact
        : CollectorTypeCopy.staleInsightsMessage;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: CollectibleShape.matRadius,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: AppTypography.deckText(textTheme, scheme).copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            CollectorTypeRevealButton(
              label: CollectorTypeCopy.revealAgain,
              onPressed: onRevealAgain,
            ),
          ],
        ),
      ),
    );
  }
}
