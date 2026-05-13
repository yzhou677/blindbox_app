import 'package:flutter/material.dart';

/// Icon + short label for scan-first hierarchy (set type, channel, etc.).
class CollectibleScanBadge extends StatelessWidget {
  const CollectibleScanBadge({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.primary.withValues(alpha: 0.82)),
        const SizedBox(width: 5),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.primary.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.06,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
