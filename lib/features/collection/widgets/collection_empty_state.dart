import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Empty shelf — visual-first, minimal copy.
class CollectionEmptyState extends StatelessWidget {
  const CollectionEmptyState({super.key, this.onAddSeries});

  final VoidCallback? onAddSeries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.shellRadius,
          boxShadow: CollectibleElevation.softCard(context),
          color: Color.lerp(
            scheme.surfaceContainerLow,
            scheme.secondaryContainer,
            isDark ? 0.08 : 0.18,
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(
              alpha: isDark ? 0.28 : 0.34,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Symbols.inventory_2_rounded,
                  size: AppIconSizes.emptyHero,
                  fill: ShelfySymbols.fillOutline,
                  weight: ShelfySymbols.emptyStateWeight,
                  grade: ShelfySymbols.grade,
                  opticalSize: ShelfySymbols.emptyStateOpticalSize,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Empty shelf',
                textAlign: TextAlign.center,
                style: AppTypography.emptyStateTitle(textTheme, scheme),
              ),
              const SizedBox(height: 28),
              if (onAddSeries != null) ...[
                FilledButton(
                  onPressed: onAddSeries,
                  child: const Text('Add series'),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton.tonal(
                onPressed: () => context.go('/home'),
                child: const Text('Discover'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
