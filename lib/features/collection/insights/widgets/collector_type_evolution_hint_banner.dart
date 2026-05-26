import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';

class CollectorTypeEvolutionHintBanner extends StatelessWidget {
  const CollectorTypeEvolutionHintBanner({super.key, this.onRevealTap});

  final VoidCallback? onRevealTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRevealTap,
        borderRadius: CollectibleShape.matRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: CollectibleShape.matRadius,
            color: scheme.tertiaryContainer.withValues(alpha: 0.35),
            border: Border.all(
              color: scheme.tertiary.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: scheme.tertiary.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    CollectorTypeCopy.evolutionHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
