import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

/// Market listing art — external photo URLs stay inside this media widget only.
///
/// Catalog/shelf surfaces use [CatalogImageFromKey]; eBay browse rows are not keyed
/// in the catalog tree, so this is the market-specific presentation boundary.
class MarketListingImage extends StatelessWidget {
  const MarketListingImage({
    super.key,
    required this.collectible,
    this.heroTag,
    required this.borderRadius,
    this.fit = BoxFit.contain,
    this.displayMode = CatalogImageDisplayMode.marketCatalogThumb,
  });

  final Collectible collectible;
  final String? heroTag;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final CatalogImageDisplayMode displayMode;

  LinearGradient _matGradient(ColorScheme scheme) {
    final a = collectible.shelfAccent ?? scheme.secondaryContainer;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(a, scheme.surface, 0.25)!,
        Color.lerp(a, scheme.surface, 0.55)!,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ref = collectible.imageUrl.trim();
    CatalogAspectImage.assertAspectPreservingFit(fit);

    final image = ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (ref.isEmpty) {
            return DecoratedBox(
              decoration: BoxDecoration(gradient: _matGradient(scheme)),
              child: Center(
                child: Icon(
                  Icons.toys_rounded,
                  size: 44,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                ),
              ),
            );
          }

          final spec = CatalogImageDisplaySpec.forMode(displayMode);
          final decodeExtent = spec.memCacheDecodeExtent(
            constraints,
            MediaQuery.devicePixelRatioOf(context),
          );
          return CatalogAspectImage.presentNetwork(
            imageUrl: ref,
            fit: fit,
            fillBounds: spec.fillsFrame,
            filterQuality: FilterQuality.medium,
            decodeExtent: decodeExtent,
            fadeInDuration: const Duration(milliseconds: 340),
            fadeOutDuration: const Duration(milliseconds: 140),
            placeholder: (context, url) {
              return DecoratedBox(
                decoration: BoxDecoration(gradient: _matGradient(scheme)),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            },
            errorWidget: (context, url, error) {
              return DecoratedBox(
                decoration: BoxDecoration(gradient: _matGradient(scheme)),
                child: Center(
                  child: Icon(
                    Icons.toys_rounded,
                    size: 44,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    final tag = heroTag;
    if (tag == null) return image;

    return Hero(
      tag: tag,
      child: Material(type: MaterialType.transparency, child: image),
    );
  }
}
