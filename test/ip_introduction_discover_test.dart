import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/drop_detail_screen.dart';
import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:blindbox_app/features/ip_profile/application/ip_profile_providers.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_repository.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/widgets/ip_introduction_info_button.dart';
import 'package:blindbox_app/features/ip_profile/widgets/ip_introduction_sheet.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/collection_fixtures.dart';

const _profile = IpIntroductionProfile(
  ipId: 'skullpanda',
  displayName: 'SKULLPANDA',
  shortDescription:
      'A quiet, surreal character exploring emotion, identity, and the space between dreams and reality.',
  styleTags: ['Surreal', 'Introspective', 'Fashion'],
  creatorDisplayName: 'XIONGMIAO',
  creatorBio: 'Artist and designer XIONGMIAO created SKULLPANDA.',
);

SeriesRelease _release({String? taxonomyIpId = 'skullpanda'}) {
  return SeriesRelease(
    dropId: 'drop_sp',
    seriesName: 'City of Night',
    brand: 'POP MART',
    ipLine: 'POP MART · SKULLPANDA',
    taxonomyIpId: taxonomyIpId,
    releaseDate: DateTime(2025, 6, 1),
    seriesImageKey: 'series_key',
    heroCollectible: Collectible(
      id: 'drop_sp',
      name: 'Hero',
      series: 'City of Night',
      brand: 'POP MART',
      releaseDate: DateTime(2025, 6, 1),
      imageUrl: '',
    ),
    lineup: List.generate(
      12,
      (i) => ReleaseLineupSlot(
        slotId: 's$i',
        name: 'Figure $i',
        imageKey: 'img_$i',
        isSecret: false,
      ),
    ),
  );
}

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() =>
      const CollectionSnapshot(shelfSeries: [], figureStates: {});
}

final class _FixtureCollectionNotifier extends CollectionNotifier {
  _FixtureCollectionNotifier(this.snapshot);

  final CollectionSnapshot snapshot;

  @override
  CollectionSnapshot build() => snapshot;
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required IpProfileRepository repo,
  SeriesRelease? release,
  CollectionSnapshot? collection,
}) async {
  final r = release ?? _release();
  final snap =
      collection ?? const CollectionSnapshot(shelfSeries: [], figureStates: {});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ipProfileRepositoryProvider.overrideWithValue(repo),
        collectionNotifierProvider.overrideWith(
          () => _FixtureCollectionNotifier(snap),
        ),
        seriesReleaseLookupProvider.overrideWith(
          (ref) =>
              (id) => id == r.dropId ? r : null,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: DropDetailScreen(releaseId: r.dropId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  // Hero art pushes the IP meta row below the default 600px test viewport.
  final meta = find.text('SKULLPANDA', skipOffstage: false);
  expect(meta, findsOneWidget);
  await tester.ensureVisible(meta);
  await tester.pump();
}

void main() {
  testWidgets('valid profile shows info icon on Series detail IP row', (
    tester,
  ) async {
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    await _pumpDetail(tester, repo: repo);
    expect(
      find.byKey(const Key('ip_introduction_info_skullpanda')),
      findsOneWidget,
    );
    expect(find.text('SKULLPANDA'), findsOneWidget);
  });

  testWidgets('Discover card does not show the IP info icon', (tester) async {
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ipProfileRepositoryProvider.overrideWithValue(repo),
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(child: LatestDropCard(release: _release())),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('ip_introduction_info_skullpanda')),
      findsNothing,
    );
    expect(find.text('SKULLPANDA'), findsOneWidget);
  });

  testWidgets('missing profile hides icon without gap placeholder', (
    tester,
  ) async {
    final repo = MemoryIpProfileRepository({});
    await _pumpDetail(tester, repo: repo);
    expect(
      find.byKey(const Key('ip_introduction_info_skullpanda')),
      findsNothing,
    );
    expect(find.text('SKULLPANDA'), findsOneWidget);
  });

  testWidgets('profile failure leaves Series detail intact', (tester) async {
    final repo = MemoryIpProfileRepository({'skullpanda': null});
    await _pumpDetail(tester, repo: repo);
    expect(find.byType(DropDetailScreen), findsOneWidget);
    expect(find.text('City of Night'), findsWidgets);
    expect(
      find.byKey(const Key('ip_introduction_info_skullpanda')),
      findsNothing,
    );
  });

  testWidgets(
    'info tap opens wrap-content sheet; empty collection omits ownership',
    (tester) async {
      final repo = MemoryIpProfileRepository({'skullpanda': _profile});
      await _pumpDetail(tester, repo: repo);

      await tester.tap(
        find.byKey(const Key('ip_introduction_info_skullpanda')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('ip_introduction_sheet')), findsOneWidget);
      expect(find.byKey(const Key('ip_introduction_title')), findsOneWidget);
      expect(find.text('Surreal'), findsOneWidget);
      expect(find.text('Introspective'), findsOneWidget);
      expect(find.text('Fashion'), findsOneWidget);
      expect(
        find.byKey(const Key('ip_introduction_short_description')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ip_introduction_creator')), findsOneWidget);
      expect(find.byKey(const Key('ip_introduction_ownership')), findsNothing);
      expect(
        find.byKey(const Key('ip_introduction_ownership_divider')),
        findsNothing,
      );
      final sheet = find.byKey(const Key('ip_introduction_sheet'));
      expect(
        find.descendant(of: sheet, matching: find.textContaining('collected')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining(' of ')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('%')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('figures')),
        findsNothing,
      );
      expect(find.textContaining('sources'), findsNothing);
      expect(find.textContaining('heroSeriesId'), findsNothing);

      final sheetTop = tester.getTopLeft(
        find.byKey(const Key('ip_introduction_sheet')),
      );
      final handleTop = tester.getTopLeft(
        find.byType(CollectibleSheetDragHandle),
      );
      final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
      expect(sheetTop.dy, greaterThan(screenHeight * 0.2));
      expect(handleTop.dy, lessThan(sheetTop.dy + 48));
    },
  );

  testWidgets('ownership shows IP-level series count without denominator', (
    tester,
  ) async {
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    final collection = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(
          id: 'a',
          catalogTemplateId: 'cat_a',
          taxonomyIpId: 'skullpanda',
        ),
        testShelfSeries(
          id: 'b',
          catalogTemplateId: 'cat_b',
          taxonomyIpId: 'skullpanda',
        ),
        testShelfSeries(
          id: 'c',
          catalogTemplateId: 'cat_c',
          taxonomyIpId: 'molly',
        ),
      ],
      figureStates: const {},
    );
    await _pumpDetail(tester, repo: repo, collection: collection);

    await tester.tap(find.byKey(const Key('ip_introduction_info_skullpanda')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('ip_introduction_ownership')), findsOneWidget);
    expect(
      find.byKey(const Key('ip_introduction_ownership_divider')),
      findsOneWidget,
    );
    expect(find.text('IN YOUR COLLECTION'), findsOneWidget);
    expect(find.text('2 series'), findsOneWidget);
    final sheet = find.byKey(const Key('ip_introduction_sheet'));
    expect(
      find.descendant(of: sheet, matching: find.textContaining('collected')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining(' of ')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('%')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('figures')),
      findsNothing,
    );
  });

  testWidgets('info icon is quiet metadata with large invisible tap target', (
    tester,
  ) async {
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    await _pumpDetail(tester, repo: repo);

    final button = find.byKey(const Key('ip_introduction_info_skullpanda'));
    expect(button, findsOneWidget);

    final iconButton = tester.widget<IconButton>(button);
    expect(
      iconButton.constraints?.minWidth,
      IpIntroductionInfoButton.tapTarget,
    );
    expect(
      iconButton.constraints?.minHeight,
      IpIntroductionInfoButton.tapTarget,
    );

    final icon = tester.widget<Icon>(
      find.descendant(of: button, matching: find.byIcon(Symbols.info_rounded)),
    );
    expect(icon.size, IpIntroductionInfoButton.visualIconSize);
    expect(IpIntroductionInfoButton.visualIconSize, inInclusiveRange(14, 16));
    expect(IpIntroductionInfoButton.tapTarget, greaterThanOrEqualTo(44));
    expect(IpIntroductionInfoButton.nameGap, 2);

    final slot = tester.widget<SizedBox>(
      find.ancestor(of: button, matching: find.byType(SizedBox)).first,
    );
    expect(slot.width, IpIntroductionInfoButton.layoutSlot);
    expect(slot.height, IpIntroductionInfoButton.layoutSlot);
  });

  testWidgets('info icon tap does not trigger parent card navigation', (
    tester,
  ) async {
    var parentTaps = 0;
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ipProfileRepositoryProvider.overrideWithValue(repo),
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: InkWell(
                onTap: () => parentTaps++,
                child: IpIntroductionInfoButton(
                  release: _release(),
                  ipDisplayName: 'SKULLPANDA',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('ip_introduction_info_skullpanda')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(parentTaps, 0);
    expect(find.byKey(const Key('ip_introduction_sheet')), findsOneWidget);
  });

  testWidgets('creator section omitted when creator is null', (tester) async {
    const noCreator = IpIntroductionProfile(
      ipId: 'skullpanda',
      displayName: 'SKULLPANDA',
      shortDescription: 'Short.',
      styleTags: ['Surreal', 'Introspective', 'Fashion'],
    );
    final repo = MemoryIpProfileRepository({'skullpanda': noCreator});
    await _pumpDetail(tester, repo: repo);
    await tester.tap(find.byKey(const Key('ip_introduction_info_skullpanda')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('ip_introduction_creator')), findsNothing);
    expect(find.text('CREATED BY'), findsNothing);
  });

  testWidgets('lookup uses taxonomyIpId not display name', (tester) async {
    final repo = MemoryIpProfileRepository({
      'skullpanda': _profile,
      'SKULLPANDA': _profile,
    });
    await _pumpDetail(
      tester,
      repo: repo,
      release: _release(taxonomyIpId: 'skullpanda'),
    );
    expect(repo.requestedIds, contains('skullpanda'));
    expect(repo.requestedIds, isNot(contains('SKULLPANDA')));
  });

  testWidgets('empty taxonomyIpId never requests a profile', (tester) async {
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    final r = _release(taxonomyIpId: null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ipProfileRepositoryProvider.overrideWithValue(repo),
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
          seriesReleaseLookupProvider.overrideWith(
            (ref) =>
                (id) => id == r.dropId ? r : null,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: DropDetailScreen(releaseId: r.dropId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final meta = find.text('SKULLPANDA', skipOffstage: false);
    expect(meta, findsOneWidget);
    await tester.ensureVisible(meta);
    await tester.pump();
    expect(repo.requestedIds, isEmpty);
    expect(
      find.byKey(
        const Key('ip_introduction_info_skullpanda'),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  testWidgets('large text sheet remains scrollable', (tester) async {
    final repo = MemoryIpProfileRepository({'skullpanda': _profile});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ipProfileRepositoryProvider.overrideWithValue(repo),
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showIpIntroductionSheet(
                      context: context,
                      profile: _profile,
                      release: _release(),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('ip_introduction_sheet')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('ip_introduction_creator')),
    );
    expect(tester.takeException(), isNull);
  });
}
