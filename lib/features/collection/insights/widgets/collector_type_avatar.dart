import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_mascot_assets.dart';
import 'package:flutter/material.dart';

/// Circular Collector Type mascot — shared rendering for all 12 types.
///
/// Clips with [ClipOval], covers with a slight overscale so PNG edge pixels
/// (black matte rings) never show. No border. Types without art return null
/// from [tryBuild] so callers can fall back to icons.
class CollectorTypeAvatar extends StatelessWidget {
  const CollectorTypeAvatar({
    super.key,
    required this.assetPath,
    required this.size,
    this.semanticLabel,
    this.scale = 1.04,
  });

  final String assetPath;
  final double size;

  /// Slight overscale inside the clip to hide PNG boundary artifacts.
  final double scale;
  final String? semanticLabel;

  /// Builds an avatar when a bundled mascot exists for [id]; otherwise null.
  static CollectorTypeAvatar? tryBuild({
    required CollectorTypeArchetypeId id,
    required double size,
    String? semanticLabel,
    double scale = 1.04,
    Key? key,
  }) {
    final path = CollectorTypeMascotAssets.assetPathFor(id);
    if (path == null) return null;
    return CollectorTypeAvatar(
      key: key ?? Key('collector_type_mascot_${id.name}'),
      assetPath: path,
      size: size,
      semanticLabel: semanticLabel,
      scale: scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: Colors.transparent,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              semanticLabel: semanticLabel,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
