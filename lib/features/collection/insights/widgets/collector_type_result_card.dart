import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_glyph.dart';
import 'package:flutter/material.dart';

class CollectorTypeResultCard extends StatelessWidget {
  const CollectorTypeResultCard({
    super.key,
    required this.identity,
  });

  final CollectorTypeIdentity identity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final archetype = identity.archetype;
    final accent = archetype.accentFor(Theme.of(context).brightness);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: CollectibleShape.shellRadius,
          color: Color.lerp(
            scheme.surfaceContainerLow,
            accent,
            Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.22),
          ),
          boxShadow: CollectibleShelfShadow.productShell(context, accent: accent),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CollectorTypeGlyph(archetype: archetype),
              const SizedBox(height: 12),
              Text(
                archetype.displayName,
                textAlign: TextAlign.center,
                style: CollectibleTypography.seriesHeroTitle(textTheme, scheme)
                    .copyWith(letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                archetype.flavorText,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
