import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _ShelfUxTestCollectionNotifier extends CollectionNotifier {
  _ShelfUxTestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

final class _DefaultShelfUiPrefsNotifier extends CollectionShelfUiPrefsNotifier {
  @override
  CollectionShelfUiPrefs build() => const CollectionShelfUiPrefs();
}

final class _AlphabeticalShelfUiPrefsNotifier
    extends CollectionShelfUiPrefsNotifier {
  @override
  CollectionShelfUiPrefs build() => const CollectionShelfUiPrefs(
        sort: CollectionShelfSort.alphabetical,
      );
}

ShelfSeries _shelfSeries({
  required String id,
  required String name,
  int figureCount = 2,
}) {
  return testShelfSeries(
    id: id,
    name: name,
    figures: [
      for (var i = 0; i < figureCount; i++)
        ShelfFigure(
          id: '${id}_fig_$i',
          seriesId: id,
          name: 'Figure $i',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: '${id}_tpl_$i',
        ),
    ],
  );
}

Map<String, TrackedFigure> _ownedAll(ShelfSeries series) {
  return {
    for (final f in series.figures)
      f.id: TrackedFigure(
        figureId: f.id,
        state: FigureCollectionState.owned,
      ),
  };
}

Future<void> _pumpCollectionScreen(
  WidgetTester tester, {
  required CollectionSnapshot snap,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _ShelfUxTestCollectionNotifier(snap),
        ),
        collectionShelfUiPrefsProvider.overrideWith(
          _DefaultShelfUiPrefsNotifier.new,
        ),
        catalogBundleProvider.overrideWith(
          (ref) async => const CatalogSeedBundle(
            brands: [],
            ips: [],
            series: [],
            figures: [],
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CollectionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _scrollToTop(WidgetTester tester) async {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  state.position.jumpTo(0);
  await tester.pump();
}

Future<void> _scrollShelfIntoView(WidgetTester tester) async {
  final scrollable = find.byType(CustomScrollView);
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 200));
}

double _top(WidgetTester tester, Finder finder) {
  return tester.getTopLeft(finder).dy;
}

Finder get _searchField => find.descendant(
      of: find.byType(AppSearchField),
      matching: find.byType(TextField),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Completed section', () {
    testWidgets('is collapsed by default and expands to show completed cards', (
      tester,
    ) async {
      final open = _shelfSeries(id: 'open', name: 'Alpha Open');
      final done = _shelfSeries(id: 'done', name: 'Bravo Done');
      await _pumpCollectionScreen(
        tester,
        snap: CollectionSnapshot(
          shelfSeries: [open, done],
          figureStates: _ownedAll(done),
        ),
      );

      await _scrollShelfIntoView(tester);

      expect(find.text('Bravo Done'), findsNothing);
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.text('In progress (1)'), findsOneWidget);
      expect(find.text('Alpha Open'), findsOneWidget);

      await tester.tap(find.text('Completed (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Bravo Done'), findsOneWidget);
    });
  });

  group('Search', () {
    testWidgets('filters live, clears to sorted view, and shows empty state', (
      tester,
    ) async {
      final alpha = _shelfSeries(id: 'a', name: 'Alpha Apple');
      final mango = _shelfSeries(id: 'm', name: 'Mango Mix');
      final zeta = _shelfSeries(id: 'z', name: 'Zeta Zzz');

      await _pumpCollectionScreen(
        tester,
        snap: CollectionSnapshot(
          shelfSeries: [zeta, mango, alpha],
          figureStates: const {},
        ),
        overrides: [
          collectionShelfUiPrefsProvider.overrideWith(
            _AlphabeticalShelfUiPrefsNotifier.new,
          ),
        ],
      );

      await _scrollShelfIntoView(tester);

      expect(_top(tester, find.text('Alpha Apple')),
          lessThan(_top(tester, find.text('Mango Mix'))));
      expect(_top(tester, find.text('Mango Mix')),
          lessThan(_top(tester, find.text('Zeta Zzz'))));

      await _scrollToTop(tester);
      await tester.enterText(_searchField, 'Apple');
      await tester.pump();
      await _scrollShelfIntoView(tester);

      expect(find.text('Alpha Apple'), findsOneWidget);
      expect(find.text('Mango Mix'), findsNothing);
      expect(find.text('Zeta Zzz'), findsNothing);

      await _scrollToTop(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await _scrollShelfIntoView(tester);

      expect(find.text('Alpha Apple'), findsOneWidget);
      expect(find.text('Mango Mix'), findsOneWidget);
      expect(find.text('Zeta Zzz'), findsOneWidget);
      expect(_top(tester, find.text('Alpha Apple')),
          lessThan(_top(tester, find.text('Zeta Zzz'))));

      await _scrollToTop(tester);
      await tester.enterText(_searchField, 'NoMatchQuery');
      await tester.pump();
      await _scrollShelfIntoView(tester);

      expect(find.text('No series match your search.'), findsOneWidget);
      expect(find.byType(SeriesShelfCard), findsNothing);
    });
  });
}
