import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/wishlist_figure_details_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WishlistFigureDetailsMetadata', () {
    test('labels regular figures by type only', () {
      const figure = ShelfFigure(
        id: 'regular',
        seriesId: 'series',
        name: 'Regular Pull',
        rarity: '1:72',
        isSecret: false,
      );

      expect(WishlistFigureDetailsMetadata.typeLabel(figure), 'Regular Figure');
    });

    test('labels secret figures by type only', () {
      const figure = ShelfFigure(
        id: 'secret',
        seriesId: 'series',
        name: 'Secret Pull',
        rarity: 'Secret',
        rarityLabel: '1 : 144',
        isSecret: true,
      );

      expect(WishlistFigureDetailsMetadata.typeLabel(figure), 'Secret Figure');
    });
  });
}
