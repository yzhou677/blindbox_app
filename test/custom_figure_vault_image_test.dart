import 'dart:io';

import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_page.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_figure_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _vaultRef = 'shelf_media/originals/customfig.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempSupport;
  late String absolutePath;

  setUp(() async {
    tempSupport = await Directory.systemTemp.createTemp('custom_fig_photo_');
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfMediaVault.testSupportOverride = tempSupport;
    await ShelfMediaVault.ensureReady();
    absolutePath = ShelfMediaVault.resolveToFilePathSync(_vaultRef)!;
    await File(absolutePath).writeAsBytes(_jpegBytes());
  });

  tearDown(() async {
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    if (await tempSupport.exists()) {
      await tempSupport.delete(recursive: true);
    }
  });

  testWidgets('shelf card shows a vault figure photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 160,
            child: ShelfFigureThumb(
              figure: _figure(localImageUri: _vaultRef),
              series: _series(),
              name: 'Custom',
              seedKey: 'custom',
            ),
          ),
        ),
      ),
    );

    expect(_shownFilePaths(tester), contains(absolutePath));
  });

  testWidgets('gallery shows a vault figure photo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 700,
          child: CatalogFigureGalleryPage(
            item: CatalogFigureGalleryItem(
              id: 'fig',
              name: 'Custom',
              catalogImageKey: 'not-a-catalog-key',
              localImageUri: _vaultRef,
            ),
          ),
        ),
      ),
    );

    expect(_shownFilePaths(tester), contains(absolutePath));
  });
}

ShelfFigure _figure({required String localImageUri}) {
  return ShelfFigure(
    id: 'fig',
    seriesId: 'series',
    name: 'Custom',
    localImageUri: localImageUri,
    imageKey: 'not-a-catalog-key',
    rarity: 'Regular',
    isSecret: false,
  );
}

ShelfSeries _series() {
  return ShelfSeries(
    id: 'series',
    name: 'My series',
    brand: 'Mine',
    ipName: 'Mine',
    figures: [_figure(localImageUri: _vaultRef)],
    shelfAccent: const Color(0xFFE8F5E9),
  );
}

List<int> _jpegBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  return img.encodeJpg(image, quality: 90);
}

Iterable<String> _shownFilePaths(WidgetTester tester) {
  return tester.widgetList<Image>(find.byType(Image)).map((image) {
    final provider = image.image;
    final current = provider is ResizeImage
        ? provider.imageProvider
        : provider;
    return current is FileImage ? current.file.path : '';
  });
}
