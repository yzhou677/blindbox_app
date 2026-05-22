import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.34),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 18),
              Text(
                'Empty shelf',
                textAlign: TextAlign.center,
                style: CollectibleTypography.seriesHeroTitle(textTheme, scheme),
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
