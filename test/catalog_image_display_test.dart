import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editorial and thumbnail surfaces use cover framing', () {
    final thumb = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.seriesCoverThumb,
    );
    final hero = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.seriesCoverHero,
    );

    expect(thumb.presentationMode, CatalogImageMode.thumbnail);
    expect(thumb.framing, CatalogImageFraming.coverFill);
    expect(thumb.fit, BoxFit.cover);
    expect(hero.presentationMode, CatalogImageMode.hero);
    expect(hero.fillsFrame, isTrue);
  });

  test('figure surfaces use contain subject framing', () {
    final figure = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.figureThumb,
    );
    final lineup = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.figureLineupCell,
    );

    expect(figure.presentationMode, CatalogImageMode.figure);
    expect(figure.framing, CatalogImageFraming.subjectContain);
    expect(figure.fit, BoxFit.contain);
    expect(figure.subjectZoom, lessThanOrEqualTo(1.1));
    expect(figure.memCacheDevicePixelScale, 2.0);
    expect(
      CatalogImageDisplaySpec.layoutExtentFor(
        CatalogImageDisplayMode.figureLineupCell,
      ),
      80,
    );
  });

  test('bundled figure assets upgrade to transparentFigure mode', () {
    final spec = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.figureThumb,
      imageRef: 'assets/catalog/figures/foo.webp',
    );
    expect(spec.presentationMode, CatalogImageMode.transparentFigure);
    expect(spec.fit, BoxFit.contain);
  });

  test('search slot uses stable square extent', () {
    expect(
      CatalogImageDisplaySpec.layoutExtentFor(
        CatalogImageDisplayMode.seriesCoverThumb,
      ),
      68,
    );
    expect(
      CatalogImageDisplaySpec.layoutExtentFor(
        CatalogImageDisplayMode.figureThumb,
      ),
      60,
    );
  });

  test('memCache decode uses long edge only to preserve aspect ratio', () {
    const spec = CatalogImageDisplaySpec(
      presentationMode: CatalogImageMode.thumbnail,
      framing: CatalogImageFraming.coverFill,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      fadeInDuration: Duration(milliseconds: 200),
      fadeOutDuration: Duration(milliseconds: 100),
      contentPadding: EdgeInsets.zero,
      matOpacity: 0.5,
      memCacheLogicalExtent: 100,
      memCacheDevicePixelScale: 1.0,
    );
    expect(
      spec.memCacheDecodeExtent(
        const BoxConstraints(maxWidth: 80, maxHeight: 60),
        2.0,
      ),
      160,
    );
    expect(
      spec.memCacheHeightFor(const BoxConstraints(maxWidth: 80), 2.0),
      isNull,
    );
  });

  test('figure decode extent includes subject zoom factor', () {
    final figure = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.figureThumb,
    );
    final coverOnly = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.seriesCoverThumb,
    );
    const constraints = BoxConstraints(maxWidth: 60, maxHeight: 60);
    expect(
      figure.memCacheDecodeExtent(constraints, 3.0),
      greaterThan(coverOnly.memCacheDecodeExtent(constraints, 3.0)!),
    );
  });
}
