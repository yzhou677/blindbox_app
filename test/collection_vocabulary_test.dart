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

  test('aggregate labels are self-explanatory', () {
    expect(CollectionVocabulary.ownedFigures, 'Owned Figures');
    expect(CollectionVocabulary.wishlistedFigures, 'Wishlisted Figures');
    expect(CollectionVocabulary.completedSeries, 'Completed Series');
    expect(CollectionVocabulary.masterComplete, 'Master Complete');
    expect(CollectionVocabulary.secretsCollected, 'Secrets Collected');
    expect(CollectionVocabulary.secretFigure, 'Secret Figure');
    expect(CollectionVocabulary.seriesCompleteBadge, '✓ Complete');
  });
}
