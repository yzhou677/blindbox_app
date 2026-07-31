import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/widgets/ip_introduction_info_button.dart';
import 'package:blindbox_app/features/ip_profile/widgets/ip_introduction_sheet.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/collection_fixtures.dart';

const _profile = IpIntroductionProfile(
  ipId: 'molly',
  displayName: 'MOLLY',
  shortDescription:
      'A cheerful fashion icon with a playful spirit and endless style.',
  styleTags: ['Fashion', 'Playful', 'Iconic'],
  creatorDisplayName: 'Kenny Wong',
  creatorBio: 'Kenny Wong created MOLLY.',
);

SeriesRelease _release() {
  return SeriesRelease(
    dropId: 'drop_molly',
    seriesName: 'Childhood Days',
    brand: 'POP MART',
    ipLine: 'POP MART · MOLLY',
    taxonomyIpId: 'molly',
    releaseDate: DateTime(2025, 6, 1),
    seriesImageKey: 'series_key',
    heroCollectible: Collectible(
      id: 'drop_molly',
      name: 'Hero',
      series: 'Childhood Days',
      brand: 'POP MART',
      releaseDate: DateTime(2025, 6, 1),
      imageUrl: '',
    ),
    lineup: const [],
  );
}

final class _SnapNotifier extends CollectionNotifier {
  _SnapNotifier(this.snapshot);
  final CollectionSnapshot snapshot;
  @override
  CollectionSnapshot build() => snapshot;
}

ThemeData _shotTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFA892CC),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3EEE6),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('IP ownership nonzero series count golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(
          id: 'a',
          catalogTemplateId: 'cat_a',
          taxonomyIpId: 'molly',
          name: 'Molly A',
        ),
        testShelfSeries(
          id: 'b',
          catalogTemplateId: 'cat_b',
          taxonomyIpId: 'molly',
          name: 'Molly B',
        ),
        testShelfSeries(
          id: 'c',
          catalogTemplateId: 'cat_c',
          taxonomyIpId: 'molly',
          name: 'Molly C',
        ),
        testShelfSeries(
          id: 'd',
          catalogTemplateId: 'cat_d',
          taxonomyIpId: 'molly',
          name: 'Molly D',
        ),
      ],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
        ],
        child: MaterialApp(
          theme: _shotTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF3EEE6),
            body: Center(
              child: RepaintBoundary(
                key: const Key('ip_intro_ownership_nonzero'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Material(
                    color: _shotTheme().colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: IpIntroductionSheet(
                      profile: _profile,
                      release: _release(),
                      scrollController: ScrollController(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('4 series'), findsOneWidget);

    await expectLater(
      find.byKey(const Key('ip_intro_ownership_nonzero')),
      matchesGoldenFile(
        '../docs/screenshots/ip_introduction_ownership/nonzero_series_count.png',
      ),
    );
  });

  testWidgets('IP ownership omitted when zero matching series golden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SnapNotifier(
              const CollectionSnapshot(shelfSeries: [], figureStates: {}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: _shotTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF3EEE6),
            body: Center(
              child: RepaintBoundary(
                key: const Key('ip_intro_ownership_zero'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Material(
                    color: _shotTheme().colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: IpIntroductionSheet(
                      profile: _profile,
                      release: _release(),
                      scrollController: ScrollController(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('ip_introduction_ownership')), findsNothing);

    await expectLater(
      find.byKey(const Key('ip_intro_ownership_zero')),
      matchesGoldenFile(
        '../docs/screenshots/ip_introduction_ownership/zero_omitted.png',
      ),
    );
  });

  testWidgets('IP info icon resized golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SnapNotifier(
              const CollectionSnapshot(shelfSeries: [], figureStates: {}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: _shotTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF3EEE6),
            body: Center(
              child: RepaintBoundary(
                key: const Key('ip_intro_info_icon'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SeriesHeroMetaBlock(
                    brand: 'POP MART',
                    ipLine: 'MOLLY',
                    trailingMeta: '12 figures',
                    ipNameTrailing: const _ForcedInfoIcon(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const Key('ip_intro_info_icon')),
      matchesGoldenFile(
        '../docs/screenshots/ip_introduction_ownership/info_icon_resized.png',
      ),
    );
  });
}

/// Layout-only stand-in matching [IpIntroductionInfoButton] metrics.
class _ForcedInfoIcon extends StatelessWidget {
  const _ForcedInfoIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: IpIntroductionInfoButton.nameGap),
      child: SizedBox(
        width: IpIntroductionInfoButton.layoutSlot,
        height: IpIntroductionInfoButton.layoutSlot,
        child: OverflowBox(
          minWidth: IpIntroductionInfoButton.tapTarget,
          maxWidth: IpIntroductionInfoButton.tapTarget,
          minHeight: IpIntroductionInfoButton.tapTarget,
          maxHeight: IpIntroductionInfoButton.tapTarget,
          alignment: Alignment.center,
          child: IconButton(
            key: const Key('ip_introduction_info_molly'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: IpIntroductionInfoButton.tapTarget,
              minHeight: IpIntroductionInfoButton.tapTarget,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: Icon(
              Symbols.info_rounded,
              size: IpIntroductionInfoButton.visualIconSize,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.48),
            ),
          ),
        ),
      ),
    );
  }
}
