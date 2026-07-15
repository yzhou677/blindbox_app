import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpretation line for dreamy mood', () {
    const profile = ShelfEmotionalProfile(
      shelfMood: ShelfMood.dreamy,
      interpretationConfidence: ShelfInterpretationConfidence.high,
      secretOwnedCount: 0,
      secretSlotCount: 0,
      seriesCompleteCount: 0,
      editorialThemes: [ShelfEditorialTheme.multiUniverse],
    );

    expect(
      ShelfEditorialVoice.shelfInterpretationLine(profile),
      contains('Soft-toned'),
    );
  });

  test('memory whisper for first secret', () {
    expect(
      ShelfEditorialVoice.memoryWhisper(
        const CollectionMemoryMoment(
          kind: CollectionMemoryMomentKind.firstSecretOwned,
        ),
      ),
      isNotEmpty,
    );
  });

  test(
    'series completion banner preserves Complete and Master Complete tiers',
    () {
      expect(
        ShelfEditorialVoice.seriesCompleteBannerTitle(chasesHome: false),
        contains('Complete'),
      );
      expect(
        ShelfEditorialVoice.seriesCompleteBannerTitle(chasesHome: false),
        isNot(contains('Master Complete')),
      );
      expect(
        ShelfEditorialVoice.seriesCompleteBannerTitle(chasesHome: true),
        contains('Master Complete'),
      );
      expect(
        ShelfEditorialVoice.seriesCompleteBannerSubtitle(chasesHome: true),
        contains('Regular and Secret'),
      );
    },
  );
}
