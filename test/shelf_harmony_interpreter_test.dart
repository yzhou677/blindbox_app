import 'package:blindbox_app/features/collectible_relationship/application/shelf_harmony_interpreter.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  test('wishlist-only changes do not create playful relationship whisper', () {
    final series = [
      testShelfSeries(
        id: 's1',
        taxonomyIpId: 'ip_a',
        figures: const [
          ShelfFigure(
            id: 'w1',
            seriesId: 's1',
            name: 'Wishlist A',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'w2',
            seriesId: 's1',
            name: 'Wishlist B',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
      testShelfSeries(id: 's2', taxonomyIpId: 'ip_b'),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: const {
        'w1': TrackedFigure(
          figureId: 'w1',
          state: FigureCollectionState.wishlist,
        ),
        'w2': TrackedFigure(
          figureId: 'w2',
          state: FigureCollectionState.wishlist,
        ),
      },
    );
    final line = interpretShelfHarmonyLine(
      snap: snap,
      profile: interpretShelf(snap),
      insights: const [
        ShelfRelationshipInsight(
          kind: ShelfRelationshipKind.complementaryMood,
          primarySeriesId: 's1',
          relatedSeriesId: 's2',
        ),
      ],
    );

    expect(line, isNot('Playful and soft-toned lineups are both present'));
    expect(line, 'Your collection blends dreamy and playful worlds');
  });
}
