import 'package:blindbox_app/core/theme/app_radii.dart';
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
          borderRadius: AppRadii.matRadius,
          color: Theme.of(context).brightness == Brightness.dark
              ? scheme.surfaceContainer
              : scheme.secondaryContainer.withValues(alpha: 0.55),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Start with your Wishlist — add figures as they come home.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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
