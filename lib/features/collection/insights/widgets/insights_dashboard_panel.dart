import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:flutter/material.dart';

/// Soft dashboard panel shared by Collection Insights surfaces.
///
/// Matches Collection / Discover card atmosphere (surface + soft elevation +
/// [AppRadii.cardRadius]) — not settings ListTiles.
class InsightsDashboardPanel extends StatelessWidget {
  const InsightsDashboardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      AppSpacing.xl,
      AppSpacing.pageHorizontal,
      AppSpacing.xl,
    ),
    this.accentBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentBorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardRadius,
        boxShadow: CollectibleElevation.softCard(context),
      ),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: accentBorder ??
                scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.38),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
