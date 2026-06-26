import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page indicator fits narrow width with many figures', (tester) async {
    final items = List<CatalogFigureGalleryItem>.generate(
      33,
      (i) => CatalogFigureGalleryItem(id: 'fig_$i', name: 'Figure $i'),
    );

    await tester.binding.setSurfaceSize(const Size(384, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogFigureGallerySheet(
          items: items,
          initialIndex: 10,
          seriesTitle: 'Nommi Sweetheart Plan Series Mini Figures Surprise Bag',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('11 of 33'), findsOneWidget);
  });
}
