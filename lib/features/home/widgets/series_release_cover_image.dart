import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';

/// Series launch cover — always [SeriesRelease.seriesImageKey], never figure art.
class SeriesReleaseCoverImage extends StatelessWidget {
  const SeriesReleaseCoverImage({
    super.key,
    required this.release,
    required this.borderRadius,
    this.heroTag,
  });

  final SeriesRelease release;
  final BorderRadius borderRadius;
  final String? heroTag;

  static String heroTagFor(SeriesRelease release) => 'series-cover-${release.dropId}';

  @override
  Widget build(BuildContext context) {
    final image = CatalogImageFromKey(
      imageKey: release.seriesImageKey,
      name: release.seriesName,
      seedKey: release.dropId,
      displayMode: CatalogImageDisplayMode.seriesCoverHero,
      borderRadius: borderRadius,
    );

    final tag = heroTag;
    if (tag == null) return image;

    return Hero(
      tag: tag,
      child: Material(type: MaterialType.transparency, child: image),
    );
  }
}
