import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
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
  });

  final String? imageRef;
  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;
  final BoxFit fit;
  final BorderRadius borderRadius;

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

    if (isAssetPath(ref)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          ref,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => CollectibleFigurePlaceholder(
            name: name,
            seedKey: seedKey,
            isSecret: isSecret,
            compact: compact,
          ),
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
