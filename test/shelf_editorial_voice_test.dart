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

  test('series completion banner preserves all completion tiers', () {
    expect(
      ShelfEditorialVoice.seriesCompleteBannerTitle(
        SeriesCompletionBannerState.completeNoSecrets,
      ),
      'Collection Complete',
    );
    expect(
      ShelfEditorialVoice.seriesCompleteBannerSubtitle(
        SeriesCompletionBannerState.completeNoSecrets,
      ),
      isNot(contains('Secret')),
    );
    expect(
      ShelfEditorialVoice.seriesCompleteBannerSubtitle(
        SeriesCompletionBannerState.completeWithSecretsRemaining,
      ),
      contains('Secret Figures can still be found later'),
    );
    expect(
      ShelfEditorialVoice.seriesCompleteBannerTitle(
        SeriesCompletionBannerState.masterComplete,
      ),
      contains('Master Complete'),
    );
    expect(
      ShelfEditorialVoice.seriesCompleteBannerSubtitle(
        SeriesCompletionBannerState.masterComplete,
      ),
      contains('Regular and Secret'),
    );
  });
}
