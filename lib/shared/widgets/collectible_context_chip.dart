import 'package:flutter/material.dart';

/// How [CollectibleContextChip] reads in the layout.
enum CollectibleContextPresentation {
  /// Pill + border — use only where tappability is real or clearly secondary.
  chip,

  /// Plain metadata (no filter affordance).
  inlineMeta,
}

/// Small icon + label anchor — theme-driven only.
class CollectibleContextChip extends StatelessWidget {
  const CollectibleContextChip({
    super.key,
    required this.icon,
    required this.label,
    this.presentation = CollectibleContextPresentation.chip,
  });

  final IconData icon;
  final String label;
  final CollectibleContextPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (presentation == CollectibleContextPresentation.inlineMeta) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.01,
              height: 1.2,
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary.withValues(alpha: 0.88)),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.04,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
