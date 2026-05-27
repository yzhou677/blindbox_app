import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CatalogImageResolver.storageFallbackOverride = null;
  });

  test('storage fallback is off by default', () {
    CatalogImageResolver.storageFallbackOverride = null;
    expect(CatalogImageResolver.storageFallbackEnabled, isFalse);
  });

  test('storage fallback override can enable probing', () {
    CatalogImageResolver.storageFallbackOverride = true;
    expect(CatalogImageResolver.storageFallbackEnabled, isTrue);
  });

  testWidgets('missing bundled key returns null without storage when fallback off', (
    tester,
  ) async {
    CatalogImageResolver.storageFallbackOverride = false;
    await CatalogImageResolver.ensureReady();

    final ref = await CatalogImageResolver.resolveFigureDisplayRef(
      'catalog_test_missing_key_never_uploaded',
    );

    expect(ref, isNull);
  });
}
