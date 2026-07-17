import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dominant IP when two series share taxonomy', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(id: 's1', taxonomyIpId: 'the_monsters'),
        testShelfSeries(id: 's2', taxonomyIpId: 'the_monsters'),
      ],
      figureStates: const {},
    );

    final profile = interpretShelf(snap);
    expect(profile.dominantIpId, 'the_monsters');
    expect(
      profile.interpretationConfidence,
      ShelfInterpretationConfidence.high,
    );
    expect(profile.themeIncludes(ShelfEditorialTheme.multiUniverse), isTrue);
  });

  test('low confidence when taxonomy sparse', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'Custom',
          brand: 'Indie',
          ipName: 'Local',
          figures: const [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE4F2EA),
        ),
      ],
      figureStates: const {},
    );

    final profile = interpretShelf(snap);
    expect(profile.interpretationConfidence, ShelfInterpretationConfidence.low);
  });

  test('chase hunter mood with multiple owned secrets', () {
    final series = testShelfSeries(
      figures: [
        const ShelfFigure(
          id: 'sec1',
          seriesId: 'series_test',
          name: 'Secret A',
          rarity: 'Secret',
          isSecret: true,
        ),
        const ShelfFigure(
          id: 'sec2',
          seriesId: 'series_test',
          name: 'Secret B',
          rarity: 'Secret',
          isSecret: true,
        ),
        const ShelfFigure(
          id: 'reg',
          seriesId: 'series_test',
          name: 'Regular',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {
        'sec1': const TrackedFigure(
          figureId: 'sec1',
          state: FigureCollectionState.owned,
        ),
        'sec2': const TrackedFigure(
          figureId: 'sec2',
          state: FigureCollectionState.owned,
        ),
      },
    );

    final profile = interpretShelf(snap);
    expect(profile.shelfMood, ShelfMood.chaseHunter);
    expect(profile.themeIncludes(ShelfEditorialTheme.secrets), isTrue);
  });

  test('wishlist-only changes do not change shelf mood or editorial line', () {
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
    final base = CollectionSnapshot(
      shelfSeries: series,
      figureStates: const {},
    );
    final withWishlist = CollectionSnapshot(
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

    final baseProfile = interpretShelf(base);
    final wishlistProfile = interpretShelf(withWishlist);

    expect(wishlistProfile.shelfMood, baseProfile.shelfMood);
    expect(
      ShelfEditorialVoice.shelfInterpretationLine(wishlistProfile),
      ShelfEditorialVoice.shelfInterpretationLine(baseProfile),
    );
    expect(
      ShelfEditorialVoice.shelfInterpretationLine(wishlistProfile),
      'Soft-toned series are a strong shelf signal',
    );
  });
}
