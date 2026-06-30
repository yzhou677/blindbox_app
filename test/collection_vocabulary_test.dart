import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('countLabel formats inline stats', () {
    expect(
      CollectionVocabulary.countLabel(11, CollectionVocabulary.figures),
      '11 Figures',
    );
    expect(
      CollectionVocabulary.countLabel(0, CollectionVocabulary.wishlist),
      '0 Wishlist',
    );
  });

  test('canonical labels stay stable', () {
    expect(CollectionVocabulary.completedSeries, 'Completed Series');
    expect(CollectionVocabulary.masterComplete, 'Master Complete');
    expect(CollectionVocabulary.secretFigure, 'Secret Figure');
    expect(CollectionVocabulary.seriesCompleteBadge, '✓ Complete');
  });
}
