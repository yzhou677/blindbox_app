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
    final snap = CollectionSnapshot(shelfSeries: [series], figureStates: const {});

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
    expect(find.textContaining('Regular Figures 0 of 3 Collected'), findsOneWidget);
    expect(find.textContaining('Secret Figures 0 of 1 Collected'), findsOneWidget);
    expect(find.text('0 of 4 Figures'), findsNothing);
    expect(find.text('Regular 0'), findsOneWidget);
    expect(find.text('Chase'), findsOneWidget);
  });

  testWidgets('header shows owned progress for master-complete series', (
    tester,
  ) async {
    final series = _seriesWithSecrets();
    final states = <String, TrackedFigure>{
      for (final f in series.figures)
        f.id: TrackedFigure(
          figureId: f.id,
          state: FigureCollectionState.owned,
        ),
    };
    final snap = CollectionSnapshot(shelfSeries: [series], figureStates: states);

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

    expect(find.textContaining('Regular Figures 3 of 3 Collected'), findsOneWidget);
    expect(find.textContaining('Secret Figures 1 of 1 Collected'), findsOneWidget);
    expect(find.text('Regular Figures (3 of 3)'), findsOneWidget);
    expect(find.text('Secret Figures (1 of 1)'), findsOneWidget);
    expect(find.textContaining('of 4 Figures'), findsNothing);
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
    final snap = CollectionSnapshot(shelfSeries: [series], figureStates: const {});

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
    expect(find.textContaining('Regular Figures 0 of 1 Collected'), findsOneWidget);
    expect(find.text('Only'), findsOneWidget);
  });
}
