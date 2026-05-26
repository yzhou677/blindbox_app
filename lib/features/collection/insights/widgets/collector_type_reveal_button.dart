import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';

class CollectorTypeRevealButton extends StatelessWidget {
  const CollectorTypeRevealButton({
    super.key,
    required this.onPressed,
    this.label,
  });

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: CollectibleShape.matRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: CollectibleShape.matRadius,
            color: scheme.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Center(
              child: Text(
                label ?? CollectorTypeCopy.revealButton,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary.withValues(alpha: 0.92),
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
