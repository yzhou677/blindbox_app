import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_browse_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card_content_meta.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_layout_controls.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_layout_host.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  List<ShelfSeries> shelf() => [
    testShelfSeries(
      id: 'a',
      name: 'Alpha Series',
      brand: 'POP MART',
      ipName: 'Hirono',
      figures: const [
        ShelfFigure(
          id: 'a1',
          seriesId: 'a',
          name: 'A1',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'a2',
          seriesId: 'a',
          name: 'A2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    ),
  ];

  Map<String, TrackedFigure> states() => {
    'a1': const TrackedFigure(
      figureId: 'a1',
      state: FigureCollectionState.owned,
      ownedQuantity: 2,
    ),
    'a2': const TrackedFigure(
      figureId: 'a2',
      state: FigureCollectionState.wishlist,
    ),
  };

  const sharedSelection = CollectionShelfCardContentSelection([
    CollectionShelfCardContentField.brand,
    CollectionShelfCardContentField.ip,
  ]);

  Set<CollectionShelfCardContentField> available() {
    return availableCollectionShelfCardContentFields(
      shelfSeries: shelf(),
      figureStates: states(),
    );
  }

  group('Layout sheet Card Content', () {
    testWidgets('shows Card Content and enforces max two selections', (
      tester,
    ) async {
      var layout = CollectionShelfLayout.grid;
      var selection = CollectionShelfCardContentSelection.empty;
      final fields = available();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CollectionShelfLayoutSheet(
                  scrollController: ScrollController(),
                  selectedLayout: layout,
                  selection: selection.sanitizePreservingUnavailable(fields),
                  available: fields,
                  onLayoutSelected: (next) {
                    setState(() => layout = next);
                  },
                  onToggleCardContent: (field) {
                    setState(() {
                      selection = selection
                          .toggle(field, available: fields)
                          .sanitizePreservingUnavailable(fields);
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(CollectionVocabulary.cardContentSectionTitle),
        findsOneWidget,
      );
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('IP'), findsOneWidget);

      Future<void> tapOption(Key key) async {
        final finder = find.byKey(key);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapOption(const Key('card_content_option_brand'));
      expect(find.text('1 of 2 selected'), findsOneWidget);
      await tapOption(const Key('card_content_option_ip'));
      expect(find.text('2 of 2 selected'), findsOneWidget);

      await tapOption(const Key('card_content_option_wishlist_count'));
      expect(selection.ordered, [
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]);
    });

    testWidgets(
      'switching layout keeps the same shared Card Content selection',
      (tester) async {
        var layout = CollectionShelfLayout.grid;
        var selection = sharedSelection;
        final fields = available();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return CollectionShelfLayoutSheet(
                    scrollController: ScrollController(),
                    selectedLayout: layout,
                    selection: selection.sanitizePreservingUnavailable(fields),
                    available: fields,
                    onLayoutSelected: (next) {
                      // Layout-only — selection is intentionally unchanged.
                      setState(() => layout = next);
                    },
                    onToggleCardContent: (_) {},
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 of 2 selected'), findsOneWidget);

        for (final next in [
          CollectionShelfLayout.list,
          CollectionShelfLayout.compactGrid,
          CollectionShelfLayout.grid,
        ]) {
          await tester.tap(
            find.byKey(Key('collection_layout_option_${next.name}')),
          );
          await tester.pumpAndSettle();
          expect(layout, next);
          expect(selection.ordered, sharedSelection.ordered);
          expect(find.text('2 of 2 selected'), findsOneWidget);
        }
      },
    );
  });

  group('Card rendering with shared Card Content', () {
    testWidgets('Grid shows selected metadata only', (tester) async {
      final series = shelf().first;
      final progress = progressForSeries(series, states());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectionSeriesCard(
              series: series,
              progress: progress,
              figureStates: states(),
              cardContent: const CollectionShelfCardContentSelection([
                CollectionShelfCardContentField.brand,
                CollectionShelfCardContentField.wishlistCount,
              ]),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Alpha Series'), findsOneWidget);
      expect(find.text('POP MART'), findsOneWidget);
      expect(find.text('1 wished'), findsOneWidget);
      expect(find.text('Hirono'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('List renders progress bar and progress text', (tester) async {
      final series = shelf().first;
      final statesMap = states();
      final resolution = resolveSeriesCompletion(series, statesMap);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectionShelfSeriesListTile(
              series: series,
              progress: progressForSeries(series, statesMap),
              figureStates: statesMap,
              cardContent: const CollectionShelfCardContentSelection([
                CollectionShelfCardContentField.ip,
              ]),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Hirono'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('collection_series_list_progress_bar')),
      );
      expect(bar.value, closeTo(resolution.progressRatio, 0.001));
      expect(find.textContaining('/'), findsOneWidget);
    });

    testWidgets('List and Grid share the same progress ratio', (tester) async {
      final series = shelf().first;
      final statesMap = states();
      final expected = resolveSeriesCompletion(series, statesMap).progressRatio;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                CollectionSeriesCard(
                  series: series,
                  progress: progressForSeries(series, statesMap),
                  figureStates: statesMap,
                  onTap: () {},
                ),
                CollectionShelfSeriesListTile(
                  series: series,
                  progress: progressForSeries(series, statesMap),
                  figureStates: statesMap,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars, hasLength(2));
      expect(bars[0].value, closeTo(expected, 0.001));
      expect(bars[1].value, closeTo(expected, 0.001));
      expect(bars[0].value, bars[1].value);
    });

    testWidgets(
      'Grid metadata sits before progress; missing meta leaves no reserved row',
      (tester) async {
        final series = shelf().first;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CollectionSeriesCard(
                series: series,
                progress: progressForSeries(series, states()),
                figureStates: states(),
                cardContent: const CollectionShelfCardContentSelection([
                  CollectionShelfCardContentField.brand,
                ]),
                onTap: () {},
              ),
            ),
          ),
        );

        final metaTop = tester
            .getTopLeft(find.byType(CollectionSeriesCardContentMeta))
            .dy;
        final barTop = tester
            .getTopLeft(find.byType(LinearProgressIndicator))
            .dy;
        expect(metaTop, lessThan(barTop));
        // Compact shared-token gap between meta and progress (not a large Spacer).
        expect(
          barTop -
              tester
                  .getBottomLeft(find.byType(CollectionSeriesCardContentMeta))
                  .dy,
          closeTo(CollectionCardTokens.metaToProgressGap, 1.5),
        );
        expect(CollectionCardTokens.metaToProgressGap, AppSpacing.lg);

        final browse = tester.widget<CollectionBrowseCard>(
          find.byType(CollectionBrowseCard),
        );
        expect(browse.expandBeforeMeta, isFalse);
        expect(browse.expandBeforeFooter, isFalse);

        // Empty selection → no meta widget / no reserved blank row.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CollectionSeriesCard(
                series: series,
                progress: progressForSeries(series, states()),
                figureStates: states(),
                onTap: () {},
              ),
            ),
          ),
        );
        expect(find.byType(CollectionSeriesCardContentMeta), findsNothing);
        expect(find.text('POP MART'), findsNothing);
      },
    );

    testWidgets('same shared metadata across Grid, Compact, and List', (
      tester,
    ) async {
      final rows = shelf();
      final lookup = ShelfBrowseProgressLookup(states());
      for (final layout in CollectionShelfLayout.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CollectionShelfSeriesLayoutHost(
                  layout: layout,
                  series: rows,
                  figureStates: states(),
                  progress: lookup,
                  cardContent: sharedSelection,
                  onOpen: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('Alpha Series'), findsOneWidget);
        expect(find.textContaining('POP MART'), findsOneWidget);
        expect(find.textContaining('Hirono'), findsOneWidget);
      }
    });

    test('prefs codec round-trips shared card content', () {
      final encoded = CollectionShelfUiPrefsCodec.encode(
        const CollectionShelfUiPrefs(
          layout: CollectionShelfLayout.list,
          cardContent: CollectionShelfCardContentPrefs(
            CollectionShelfCardContentSelection([
              CollectionShelfCardContentField.wishlistCount,
              CollectionShelfCardContentField.duplicateCount,
            ]),
          ),
        ),
      );
      final decoded = CollectionShelfUiPrefsCodec.decode(encoded);
      expect(decoded.layout, CollectionShelfLayout.list);
      expect(decoded.cardContentSelection.ordered, [
        CollectionShelfCardContentField.wishlistCount,
        CollectionShelfCardContentField.duplicateCount,
      ]);
    });
  });
}
