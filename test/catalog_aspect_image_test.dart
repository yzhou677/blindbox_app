import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';



void main() {

  test('cover and contain preserve aspect; fill does not', () {

    expect(CatalogAspectImage.isAspectPreservingFit(BoxFit.cover), isTrue);

    expect(CatalogAspectImage.isAspectPreservingFit(BoxFit.contain), isTrue);

    expect(CatalogAspectImage.isAspectPreservingFit(BoxFit.scaleDown), isTrue);

    expect(CatalogAspectImage.isAspectPreservingFit(BoxFit.fill), isFalse);

  });



  test('memCache height stays unused in display spec', () {

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

    );

    expect(spec.memCacheHeightFor(const BoxConstraints(maxWidth: 100), 2.0), isNull);

  });

}


