import 'dart:io';

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_version.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_edge_feather.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_figure_stage.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Foreground [BoxFit.contain] with edge feather on fitted art bounds.
///
/// One [Image] resolve; [FittedBox] derives contain layout synchronously after
/// decode — no separate dimension listener or post-load [setState].
class CatalogImmersiveFeatheredSubject extends StatelessWidget {
  const CatalogImmersiveFeatheredSubject({
    super.key,
    required this.imageProvider,
    required this.slotWidth,
    required this.slotHeight,
    this.filterQuality = FilterQuality.high,
    this.decodeExtent,
    this.featherFraction = CatalogImmersiveFigureStage.edgeFeatherFraction,
    this.placeholder,
    this.errorBuilder,
  });

  final ImageProvider imageProvider;
  final double slotWidth;
  final double slotHeight;
  final FilterQuality filterQuality;
  final int? decodeExtent;
  final double featherFraction;
  final WidgetBuilder? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;

  ImageProvider get _resolvedProvider => decodeExtent != null
      ? ResizeImage(imageProvider, width: decodeExtent)
      : imageProvider;

  /// Matches [FittedBox] + [BoxFit.contain] math — kept for unit tests.
  @visibleForTesting
  static Size fittedDestinationSize({
    required Size sourceSize,
    required double slotWidth,
    required double slotHeight,
  }) {
    if (slotWidth <= 0 || slotHeight <= 0) {
      return Size.zero;
    }
    if (sourceSize.width <= 0 || sourceSize.height <= 0) {
      return Size(slotWidth, slotHeight);
    }
    return applyBoxFit(
      BoxFit.contain,
      sourceSize,
      Size(slotWidth, slotHeight),
    ).destination;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: slotWidth,
      height: slotHeight,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (placeholder != null)
            Positioned.fill(child: placeholder!(context)),
          FittedBox(
            fit: BoxFit.contain,
            child: CatalogImmersiveEdgeFeather(
              featherFraction: featherFraction,
              child: Image(
                image: _resolvedProvider,
                filterQuality: filterQuality,
                gaplessPlayback: true,
                errorBuilder: errorBuilder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves a display [ImageProvider] for gallery immersive layers.
abstract final class CatalogImmersiveImageProviders {
  CatalogImmersiveImageProviders._();

  static ImageProvider network(String url, {String? cacheKey}) {
    return CachedNetworkImageProvider(url, cacheKey: cacheKey ?? url);
  }

  static ImageProvider asset(String path) => AssetImage(path);

  static ImageProvider file(File file) => FileImage(file);

  static ImageProvider fromDisplayRef(
    String ref, {
    String? imageVersion,
  }) {
    final trimmed = ref.trim();
    if (CollectibleThumbImage.isAssetPath(trimmed)) {
      return asset(trimmed);
    }
    if (!kIsWeb && DeviceLocalImageRef.looksLikeDevicePath(trimmed)) {
      return file(File(DeviceLocalImageRef.normalizeToFilePath(trimmed)));
    }
    return network(
      trimmed,
      cacheKey: CatalogImageVersion.networkCacheKey(trimmed, imageVersion),
    );
  }
}
