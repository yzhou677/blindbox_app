import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogImageResolver', () {
    test('maps opaque keys to deterministic bundled paths', () {
      expect(
        CatalogImageResolver.figureAsset('the_monsters_exciting_macaron_labubu_soymilk'),
        'assets/catalog/figures/the_monsters_exciting_macaron_labubu_soymilk.png',
      );
      expect(
        CatalogImageResolver.seriesAsset('the_monsters_exciting_macaron'),
        'assets/catalog/series/the_monsters_exciting_macaron.png',
      );
    });

    test('legacy thumbnail paths yield stems for migration reads', () {
      expect(
        CatalogImageResolver.imageKeyFromLegacyThumbnailAsset(
          r'assets\catalog\figures\foo_bar.png',
        ),
        'foo_bar',
      );
      expect(CatalogImageResolver.imageKeyFromLegacyThumbnailAsset('https://cdn/img.png'), '');
    });
  });
}
