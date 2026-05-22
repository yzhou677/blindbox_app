import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('series and figure presets use contain fit for transparent art', () {
    final series = CatalogImageDisplaySpec.forMode(CatalogImageDisplayMode.seriesCoverThumb);
    final figure = CatalogImageDisplaySpec.forMode(CatalogImageDisplayMode.figureThumb);
    final hero = CatalogImageDisplaySpec.forMode(CatalogImageDisplayMode.seriesCoverHero);

    expect(series.fit, BoxFit.contain);
    expect(figure.fit, BoxFit.contain);
    expect(hero.fit, BoxFit.contain);
    expect(hero.contentPadding.left, greaterThan(series.contentPadding.left));
  });

  test('memCache caps decode size from logical extent', () {
    const spec = CatalogImageDisplaySpec(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      fadeInDuration: Duration(milliseconds: 200),
      fadeOutDuration: Duration(milliseconds: 100),
      contentPadding: EdgeInsets.zero,
      matOpacity: 0.5,
      memCacheLogicalExtent: 100,
    );
    expect(spec.memCacheWidthFor(const BoxConstraints(maxWidth: 80), 2.0), 320);
    expect(spec.memCacheWidthFor(const BoxConstraints(), 2.0), 400);
  });
}
