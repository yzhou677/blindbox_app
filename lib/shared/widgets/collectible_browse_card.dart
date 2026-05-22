import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:flutter/material.dart';

/// Series-centric browse row shell — search, recommendations, market-adjacent tiles.
class CollectibleBrowseCard extends StatelessWidget {
  const CollectibleBrowseCard({
    super.key,
    required this.child,
    required this.onTap,
    this.borderColor,
    this.fillColor,
    this.fillGradient,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
  });

  final Widget child;
  final VoidCallback onTap;
  final Color? borderColor;
  final Color? fillColor;
  final Gradient? fillGradient;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = AppRadii.cardRadius;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: CollectibleElevation.softCard(context),
      ),
      child: Material(
        color: fillGradient == null
            ? (fillColor ?? scheme.surfaceContainerLow)
            : Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: fillGradient,
              color: fillGradient == null
                  ? (fillColor ?? scheme.surfaceContainerLow)
                  : null,
              border: Border.all(
                color: borderColor ??
                    scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
