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
          'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.jpeg',
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

    test('storage probe order lists all supported extensions per imageKey', () {
      final paths = [
        for (final ext in CatalogImageResolver.assetExtensions)
          CatalogImageResolver.storageObjectPath(
            kind: CatalogImageKind.series,
            imageKey: 'crybaby_cry_me_an_ocean',
            extension: ext,
          ),
      ];
      expect(paths, [
        'catalog/series/crybaby_cry_me_an_ocean.avif',
        'catalog/series/crybaby_cry_me_an_ocean.webp',
        'catalog/series/crybaby_cry_me_an_ocean.png',
        'catalog/series/crybaby_cry_me_an_ocean.jpg',
        'catalog/series/crybaby_cry_me_an_ocean.jpeg',
      ]);
    });

    test('storageObjectPath is deterministic from imageKey kind and extension', () {
      expect(
        CatalogImageResolver.storageObjectPath(
          kind: CatalogImageKind.series,
          imageKey: 'the_monsters_exciting_macaron',
          extension: '.webp',
        ),
        'catalog/series/the_monsters_exciting_macaron.webp',
      );
      expect(
        CatalogImageResolver.storageObjectPath(
          kind: CatalogImageKind.figure,
          imageKey: 'the_monsters_exciting_macaron_labubu_soymilk',
          extension: 'png',
        ),
        'catalog/figures/the_monsters_exciting_macaron_labubu_soymilk.png',
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
