import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _SheetTestNotifier extends CollectionNotifier {
  _SheetTestNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

ShelfSeries _seriesWithSecrets() {
  return testShelfSeries(
    id: 'sheet_sections',
    name: 'Macaron',
    catalogTemplateId: null,
    notes: 'Found this one while visiting Chicago.',
    figures: [
      for (var i = 0; i < 3; i++)
        ShelfFigure(
          id: 'sheet_sections_reg_$i',
          seriesId: 'sheet_sections',
          name: 'Regular $i',
          rarity: 'Regular',
          isSecret: false,
        ),
      const ShelfFigure(
        id: 'sheet_sections_sec_0',
        seriesId: 'sheet_sections',
        name: 'Chase',
        rarity: 'Secret',
        isSecret: true,
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('splits regular and secret figures with section labels', (
    tester,
  ) async {
    final series = _seriesWithSecrets();
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Regular Figures (0 of 3)'), findsOneWidget);
    expect(find.text('Secret Figures (0 of 1)'), findsOneWidget);
    expect(
      find.textContaining('Regular Figures 0 of 3 Collected'),
      findsOneWidget,
    );
    // Header hides Secret summary until at least one Secret is owned.
    expect(
      find.textContaining('Secret Figures 0 of 1 Collected'),
      findsNothing,
    );
    expect(find.text('0 of 4 Figures'), findsNothing);
    expect(find.text('Regular 0'), findsOneWidget);
    expect(find.text('Chase'), findsOneWidget);
    expect(find.text('Found this one while visiting Chicago.'), findsOneWidget);
  });

  testWidgets('omits series note section when note is empty', (tester) async {
    final series = testShelfSeries(
      id: 'empty_note',
      name: 'Plain',
      catalogTemplateId: null,
      notes: '   ',
      figures: const [
        ShelfFigure(
          id: 'empty_note_f0',
          seriesId: 'empty_note',
          name: 'Only',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('   '), findsNothing);
    expect(find.text('Only'), findsOneWidget);
  });

  testWidgets('existing long series notes render without truncation', (
    tester,
  ) async {
    final note = 'Memory ' * 45;
    final series = testShelfSeries(
      id: 'long_note',
      name: 'Long Note',
      catalogTemplateId: null,
      notes: note,
      figures: const [
        ShelfFigure(
          id: 'long_note_f0',
          seriesId: 'long_note',
          name: 'Only',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(note.trim()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog series does not render notes as description copy', (
    tester,
  ) async {
    final series = testShelfSeries(
      id: 'catalog_note',
      name: 'Catalog Note',
      notes: 'Nearby in the quiet Dimoo world of collectibles',
      figures: const [
        ShelfFigure(
          id: 'catalog_note_f0',
          seriesId: 'catalog_note',
          name: 'Only',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Nearby in the quiet Dimoo world of collectibles'),
      findsNothing,
    );
    expect(find.text('Only'), findsOneWidget);
  });

  testWidgets('regular completion copy only appears in the banner', (
    tester,
  ) async {
    final series = _seriesWithSecrets();
    final states = <String, TrackedFigure>{
      for (final f in series.figures.where((f) => !f.isSecret))
        f.id: TrackedFigure(figureId: f.id, state: FigureCollectionState.owned),
    };
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: states,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Macaron is now Complete'), findsNothing);
    expect(find.text('This series is Complete'), findsNothing);
    expect(find.text('Complete -- every Regular home'), findsOneWidget);
    expect(
      find.text('Secret Figures can still be found later.'),
      findsOneWidget,
    );
  });

  testWidgets('header shows owned progress for master-complete series', (
    tester,
  ) async {
    final series = _seriesWithSecrets();
    final states = <String, TrackedFigure>{
      for (final f in series.figures)
        f.id: TrackedFigure(figureId: f.id, state: FigureCollectionState.owned),
    };
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: states,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Regular Figures 3 of 3 Collected'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Secret Figures 1 of 1 Collected'),
      findsOneWidget,
    );
    expect(find.text('Regular Figures (3 of 3)'), findsOneWidget);
    expect(find.text('Secret Figures (1 of 1)'), findsOneWidget);
    expect(find.textContaining('of 4 Figures'), findsNothing);
    expect(find.text('Macaron is now Master Complete'), findsNothing);
    expect(find.text('This series is Master Complete'), findsNothing);
    expect(find.textContaining('Master Complete'), findsOneWidget);
    expect(
      find.text('Every Regular and Secret figure has found its place.'),
      findsOneWidget,
    );
  });

  testWidgets('no section labels when series has no secrets', (tester) async {
    final series = testShelfSeries(
      id: 'no_secret',
      name: 'Plain',
      figures: [
        const ShelfFigure(
          id: 'no_secret_f0',
          seriesId: 'no_secret',
          name: 'Only',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SheetTestNotifier(snap),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectibleSheetScope(
              scrollController: ScrollController(),
              child: SeriesFiguresSheet(seriesId: series.id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Regular Figures'), findsNothing);
    expect(find.text('Secret Figures'), findsNothing);
    expect(find.textContaining('Secret Figures'), findsNothing);
    expect(
      find.textContaining('Regular Figures 0 of 1 Collected'),
      findsOneWidget,
    );
    expect(find.text('Only'), findsOneWidget);
  });
}
