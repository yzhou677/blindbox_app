import 'package:flutter/material.dart';

/// Gentle prompt when the library has no pulls logged yet.
class CollectionWarmStartBanner extends StatelessWidget {
  const CollectionWarmStartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.secondaryContainer.withValues(alpha: 0.35),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.waving_hand_rounded,
                color: scheme.onSecondaryContainer.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open a series and tap figures to mark collected or wish list.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
