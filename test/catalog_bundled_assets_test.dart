import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogImageResolver', () {
    test('candidate paths follow format priority', () {
      expect(
        CatalogImageResolver.candidatePaths(
          CatalogImageResolver.figuresRoot,
          'the_monsters_exciting_macaron_soymilk',
        ).toList(),
        [
          'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.avif',
          'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.webp',
          'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.png',
          'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.jpg',
        ],
      );
    });

    test('before ensureReady, sync paths prefer highest-priority extension', () {
      expect(
        CatalogImageResolver.figureAsset('foo'),
        'assets/catalog/figures/foo.avif',
      );
      expect(
        CatalogImageResolver.seriesAsset('bar'),
        'assets/catalog/series/bar.avif',
      );
    });

    test('legacy thumbnail paths yield stems for migration reads', () {
      expect(
        CatalogImageResolver.imageKeyFromLegacyThumbnailAsset(
          r'assets\catalog\figures\foo_bar.png',
        ),
        'foo_bar',
      );
      expect(
        CatalogImageResolver.imageKeyFromLegacyThumbnailAsset(
          'assets/catalog/figures/foo_bar.avif',
        ),
        'foo_bar',
      );
      expect(CatalogImageResolver.imageKeyFromLegacyThumbnailAsset('https://cdn/img.png'), '');
    });
  });
}
