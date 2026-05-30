import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
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
    this.helperLine,
  });

  final CollectorTypeIdentity identity;
  final String? helperLine;

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
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: CollectibleShelfShadow.productShell(
            context,
            accent: accent,
          ),
        ),
        child: Padding(
          // Intentionally wider than pageHorizontal — the result card is a
          // featured hero surface that benefits from extra breathing room.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl + AppSpacing.xs, // 22
            AppSpacing.xl + AppSpacing.sm, // 28
            AppSpacing.xl + AppSpacing.xs, // 22
            AppSpacing.xxl, // 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CollectorTypeGlyph(archetype: archetype),
              const SizedBox(height: AppSpacing.md),
              Text(
                archetype.displayName,
                textAlign: TextAlign.center,
                style: CollectibleTypography.seriesHeroTitle(
                  textTheme,
                  scheme,
                ).copyWith(letterSpacing: -0.3),
              ),
              const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              Text(
                archetype.flavorText,
                textAlign: TextAlign.center,
                style: AppTypography.insightsFlavor(textTheme, scheme),
              ),
              if (helperLine != null && helperLine!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  helperLine!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
