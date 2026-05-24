import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/market/presentation/market_listing_image.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

/// Showcase mat + listing photo — shared by browse cards and Chasers rail.
class MarketListingShowcaseThumb extends StatelessWidget {
  const MarketListingShowcaseThumb({
    super.key,
    required this.collectible,
    required this.extent,
    this.heroTag,
    this.displayMode = CatalogImageDisplayMode.marketCatalogThumb,
  });

  final Collectible collectible;
  final double extent;
  final String? heroTag;
  final CatalogImageDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = collectible.shelfAccent ?? scheme.tertiaryContainer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: extent,
      height: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.matRadius,
          color: Color.lerp(
            scheme.surfaceContainerHighest,
            accent,
            isDark ? 0.1 : 0.14,
          )!.withValues(alpha: isDark ? 0.45 : 0.55),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: AppRadii.insetRadius,
            child: ColoredBox(
              color: scheme.surface.withValues(alpha: 0.35),
              child: MarketListingImage(
                collectible: collectible,
                heroTag: heroTag,
                borderRadius: BorderRadius.zero,
                fit: BoxFit.contain,
                displayMode: displayMode,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
