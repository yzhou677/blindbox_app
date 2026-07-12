import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_button.dart';
import 'package:flutter/material.dart';

export 'package:blindbox_app/features/collection/insights/widgets/insights_archived_scope.dart'
    show collectorTypeStaleInsightsOpacity;

/// Active stale-analysis card — the only prominent action while Insights wait.
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
        color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.22),
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
