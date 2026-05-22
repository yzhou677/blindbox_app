import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

/// Network image with soft pastel loading / error states; optional [heroTag] for transitions.
class CollectibleNetworkImage extends StatelessWidget {
  const CollectibleNetworkImage({
    super.key,
    required this.collectible,
    this.heroTag,
    required this.borderRadius,
    this.fit = BoxFit.contain,
  });

  final Collectible collectible;
  final String? heroTag;
  final BorderRadius borderRadius;
  final BoxFit fit;

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
    CatalogAspectImage.assertAspectPreservingFit(fit);
    final image = ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final spec = CatalogImageDisplaySpec.forMode(
            CatalogImageDisplayMode.seriesCoverHero,
          );
          final decodeExtent = spec.memCacheDecodeExtent(constraints, dpr);
          return CatalogAspectImage.presentNetwork(
            imageUrl: collectible.imageUrl,
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

    if (heroTag == null) return image;

    return Hero(
      tag: heroTag!,
      child: Material(type: MaterialType.transparency, child: image),
    );
  }
}
