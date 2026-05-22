import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_resolved_image.dart';
import 'collectible_local_file_image_stub.dart'
    if (dart.library.io) 'collectible_local_file_image.dart' as shelf_local_image;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network URL or bundled asset path (`assets/...`) for figure / series art.
class CollectibleThumbImage extends StatelessWidget {
  const CollectibleThumbImage({
    super.key,
    required this.imageRef,
    required this.name,
    required this.seedKey,
    this.isSecret = false,
    this.compact = false,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.catalogDisplayMode,
  });

  final String? imageRef;
  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// When set, bundled/remote catalog art uses [CatalogImageDisplaySpec] (not [fit]).
  final CatalogImageDisplayMode? catalogDisplayMode;

  static bool isAssetPath(String? ref) {
    final r = ref?.trim();
    return r != null && r.isNotEmpty && r.startsWith('assets/');
  }

  @override
  Widget build(BuildContext context) {
    final ref = imageRef?.trim();
    if (ref == null || ref.isEmpty) {
      return CollectibleFigurePlaceholder(
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
      );
    }

    if (DeviceLocalImageRef.looksLikeDevicePath(ref)) {
      final path = DeviceLocalImageRef.normalizeToFilePath(ref);
      return shelf_local_image.buildCollectibleLocalFileImage(
        filePath: path,
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
        fit: fit,
        borderRadius: borderRadius,
      );
    }

    if (catalogDisplayMode != null) {
      return CatalogResolvedImage(
        imageRef: ref,
        spec: CatalogImageDisplaySpec.forMode(catalogDisplayMode!),
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
        borderRadius: borderRadius,
      );
    }

    if (isAssetPath(ref)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          ref,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('CollectibleThumbImage: failed to load asset "$ref": $error');
            return CollectibleFigurePlaceholder(
              name: name,
              seedKey: seedKey,
              isSecret: isSecret,
              compact: compact,
            );
          },
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: ref,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 180),
        errorWidget: (context, url, error) => CollectibleFigurePlaceholder(
          name: name,
          seedKey: seedKey,
          isSecret: isSecret,
          compact: compact,
        ),
      ),
    );
  }
}
