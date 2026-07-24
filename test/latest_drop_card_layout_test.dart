import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SeriesRelease _release({
  required String dropId,
  required String seriesName,
  int figureCount = 3,
}) {
  return SeriesRelease(
    dropId: dropId,
    seriesName: seriesName,
    brand: 'POP MART',
    ipLine: 'THE MONSTERS',
    releaseDate: DateTime(2026, 5, 12),
    seriesImageKey: 'series_key',
    heroCollectible: Collectible(
      id: dropId,
      name: 'Hero',
      series: seriesName,
      brand: 'POP MART',
      releaseDate: DateTime(2026, 5, 12),
      imageUrl: '',
    ),
    lineup: List.generate(
      figureCount,
      (i) => ReleaseLineupSlot(
        slotId: 'slot_$i',
        name: 'Figure $i',
        imageKey: 'img_$i',
        isSecret: false,
      ),
    ),
  );
}

void main() {
  testWidgets('LatestDropCard uses identical fixed rail tile size', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              height: FeedRhythm.homeSeriesRailHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  LatestDropCard(
                    release: _release(dropId: 'a', seriesName: 'Short title'),
                  ),
                  LatestDropCard(
                    release: _release(
                      dropId: 'b',
                      seriesName:
                          'An Extremely Long Series Title That Should Clamp Cleanly Across Two Lines',
                      figureCount: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LatestDropCard), findsNWidgets(2));

    for (final finder in [
      find.byType(LatestDropCard).at(0),
      find.byType(LatestDropCard).at(1),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, FeedRhythm.homeSeriesRailCardWidth);
      expect(size.height, FeedRhythm.homeSeriesRailHeight);
    }

    final shortSize = tester.getSize(find.byType(LatestDropCard).at(0));
    final longSize = tester.getSize(find.byType(LatestDropCard).at(1));
    expect(shortSize, longSize);
  });

  testWidgets('LatestDropCard keeps fixed size at text scale 1.3', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SizedBox(
                height: FeedRhythm.homeSeriesRailHeight,
                child: LatestDropCard(
                  release: _release(
                    dropId: 'scaled',
                    seriesName: 'Scaled Long Series Title For Density Check',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final size = tester.getSize(find.byType(LatestDropCard));
    expect(size.width, FeedRhythm.homeSeriesRailCardWidth);
    expect(size.height, FeedRhythm.homeSeriesRailHeight);
  });
}
