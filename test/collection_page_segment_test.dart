import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/widgets/collection_page_segment_control.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _SegmentTestCollectionNotifier extends CollectionNotifier {
  _SegmentTestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

final class _DefaultShelfUiPrefsNotifier
    extends CollectionShelfUiPrefsNotifier {
  @override
  CollectionShelfUiPrefs build() => const CollectionShelfUiPrefs();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  Future<void> pumpScreen(WidgetTester tester, CollectionSnapshot snap) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SegmentTestCollectionNotifier(snap),
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
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  ({
    Rect summary,
    Rect segment,
    double scrollOffset,
    EdgeInsets padding,
    EdgeInsets viewInsets,
  })
  collectionGeometry(WidgetTester tester) {
    final summary = find.byKey(const Key('collection_insights_compact_glance'));
    final segment = find.byType(CollectionPageSegmentControl);
    final screenContext = tester.element(find.byType(CollectionScreen));
    final mediaQuery = MediaQuery.of(screenContext);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CollectionScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    return (
      summary: tester.getRect(summary),
      segment: tester.getRect(segment),
      scrollOffset: scrollable.position.pixels,
      padding: mediaQuery.padding,
      viewInsets: mediaQuery.viewInsets,
    );
  }

  Future<void> openPhotoSourceSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('collection_header_add_series')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('catalog-photo-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('photo-source-sheet')), findsOneWidget);
  }

  Future<void> closeAddSeriesSheet(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Add a series'), findsNothing);
  }

  testWidgets('Add a Series camera entry uses shared pre-capture guidance', (
    tester,
  ) async {
    final series = testShelfSeries(id: 's1', name: 'Dimoo One');
    await pumpScreen(
      tester,
      CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
    );
    await openPhotoSourceSheet(tester);

    await tester.tap(find.text('Take Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Keep the collectible centered and in focus.'),
      findsOneWidget,
    );
    expect(find.text('Open Camera'), findsOneWidget);
  });

  void expectCollectionGeometryUnchanged(
    WidgetTester tester,
    ({
      Rect summary,
      Rect segment,
      double scrollOffset,
      EdgeInsets padding,
      EdgeInsets viewInsets,
    })
    before,
  ) {
    final after = collectionGeometry(tester);
    expect(after.summary, before.summary);
    expect(after.segment, before.segment);
    expect(after.scrollOffset, before.scrollOffset);
    expect(after.padding, before.padding);
    expect(after.viewInsets, before.viewInsets);
    expect(after.summary.bottom, lessThanOrEqualTo(after.segment.top));
  }

  testWidgets('Collection page defaults to Shelf with segment control', (
    tester,
  ) async {
    final series = testShelfSeries(id: 's1', name: 'Dimoo One');
    await pumpScreen(
      tester,
      CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {
          for (final f in series.figures)
            f.id: TrackedFigure(
              figureId: f.id,
              state: FigureCollectionState.owned,
            ),
        },
      ),
    );

    expect(find.byType(CollectionPageSegmentControl), findsOneWidget);
    expect(find.byKey(const Key('shelfy_segmented_control')), findsOneWidget);
    expect(find.byType(SegmentedButton<CollectionPageSegment>), findsNothing);
    expect(find.text('Shelf'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.byType(AppSearchField), findsOneWidget);
    expect(find.text('Add series'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.screenSubtitle), findsNothing);
  });

  testWidgets('Insights segment shows existing insights body', (tester) async {
    final series = testShelfSeries(id: 's1', name: 'Dimoo One');
    await pumpScreen(
      tester,
      CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
    );

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text(CollectorTypeCopy.screenTitle), findsWidgets);
    expect(find.text(CollectorTypeCopy.revealButton), findsOneWidget);
    expect(find.text(CollectorTypeCopy.journeyTitle), findsOneWidget);
    expect(find.text('Add series'), findsNothing);
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.enabled, isFalse);
    expect(searchField.showCursor, isFalse);
    // Summary stays above the segment on both tabs.
    expect(
      find.byKey(const Key('collection_insights_compact_glance')),
      findsOneWidget,
    );
  });

  testWidgets('first-use empty state hides search and summary', (tester) async {
    await pumpScreen(
      tester,
      const CollectionSnapshot(shelfSeries: [], figureStates: {}),
    );

    expect(find.byType(AppSearchField), findsNothing);
    expect(
      find.byKey(const Key('collection_summary_stats_card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('collection_insights_compact_glance')),
      findsNothing,
    );
    expect(find.byType(CollectionPageSegmentControl), findsOneWidget);
  });

  testWidgets(
    'wishlist content keeps search and summary visible when shelf is empty',
    (tester) async {
      await pumpScreen(
        tester,
        CollectionSnapshot(
          shelfSeries: const [],
          figureStates: const {},
          seriesWishlist: const [
            WishlistedCatalogSeries(
              catalogSeriesId: 'saved-series',
              name: 'Saved Series',
              brand: 'POP MART',
              ipName: 'Molly',
              imageKey: 'saved-series',
              addedAtMicros: 10,
            ),
          ],
        ),
      );

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(
        find.byKey(const Key('collection_insights_compact_glance')),
        findsOneWidget,
      );
      expect(find.byType(CollectionPageSegmentControl), findsOneWidget);

      await tester.tap(find.text('Insights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(AppSearchField), findsOneWidget);
      final insightsSearchField = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(insightsSearchField.enabled, isFalse);
      expect(
        find.byKey(const Key('collection_insights_compact_glance')),
        findsOneWidget,
      );

      await tester.tap(find.text('Wishlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(
        find.byKey(const Key('collection_summary_stats_card')),
        findsOneWidget,
      );
      expect(find.text('Your wishlist is empty.'), findsNothing);
    },
  );

  testWidgets('header order keeps summary above Shelf Insights segment', (
    tester,
  ) async {
    final series = testShelfSeries(id: 's1', name: 'Dimoo One');
    await pumpScreen(
      tester,
      CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
    );

    final searchY = tester.getTopLeft(find.byType(AppSearchField)).dy;
    final summaryY = tester
        .getTopLeft(find.byKey(const Key('collection_insights_compact_glance')))
        .dy;
    final segmentY = tester
        .getTopLeft(find.byType(CollectionPageSegmentControl))
        .dy;
    final addSeriesY = tester.getTopLeft(find.text('Add series')).dy;

    expect(searchY, lessThan(summaryY));
    expect(summaryY, lessThan(segmentY));
    expect(segmentY, lessThan(addSeriesY));
  });

  testWidgets('summary to segment spacing is consistent across tabs', (
    tester,
  ) async {
    final series = testShelfSeries(id: 's1', name: 'Dimoo One');
    await pumpScreen(
      tester,
      CollectionSnapshot(
        shelfSeries: [series],
        figureStates: const {},
        seriesWishlist: const [
          WishlistedCatalogSeries(
            catalogSeriesId: 'saved-series',
            name: 'Saved Series',
            brand: 'POP MART',
            ipName: 'Molly',
            imageKey: 'saved-series',
            addedAtMicros: 10,
          ),
        ],
      ),
    );

    double currentSummaryToSegmentGap() {
      final expandedSummary = find.byKey(
        const Key('collection_summary_stats_card'),
      );
      final compactSummary = find.byKey(
        const Key('collection_insights_compact_glance'),
      );
      final summaryFinder = expandedSummary.evaluate().isNotEmpty
          ? expandedSummary
          : compactSummary;
      final summaryBottom = tester.getBottomLeft(summaryFinder).dy;
      final segmentTop = tester
          .getTopLeft(find.byType(CollectionPageSegmentControl))
          .dy;
      return segmentTop - summaryBottom;
    }

    final shelfGap = currentSummaryToSegmentGap();

    await tester.tap(find.text('Insights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final insightsGap = currentSummaryToSegmentGap();

    await tester.tap(find.text('Wishlist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final wishlistGap = currentSummaryToSegmentGap();

    expect(insightsGap, closeTo(shelfGap, 1));
    expect(wishlistGap, closeTo(shelfGap, 1));
  });

  testWidgets(
    'photo source dismissal paths preserve Collection summary geometry',
    (tester) async {
      final series = testShelfSeries(id: 's1', name: 'Dimoo One');
      await pumpScreen(
        tester,
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      final before = collectionGeometry(tester);
      expect(before.summary.bottom, lessThanOrEqualTo(before.segment.top));

      Future<void> verifyDismiss(
        Future<void> Function() dismissPhotoSource,
      ) async {
        await openPhotoSourceSheet(tester);
        await dismissPhotoSource();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const Key('photo-source-sheet')), findsNothing);
        expectCollectionGeometryUnchanged(tester, before);
        await closeAddSeriesSheet(tester);
        expectCollectionGeometryUnchanged(tester, before);
      }

      await verifyDismiss(() async {
        await tester.drag(
          find.byKey(const Key('photo-source-drag-region')),
          const Offset(0, 180),
        );
      });
      await verifyDismiss(() async {
        await tester.fling(
          find.byKey(const Key('photo-source-drag-region')),
          const Offset(0, 60),
          3000,
        );
      });
      await verifyDismiss(() async {
        await tester.tapAt(const Offset(4, 4));
      });
      await verifyDismiss(() async {
        await tester.tap(find.text('Cancel'));
      });
      await verifyDismiss(() async {
        await tester.binding.handlePopRoute();
      });
      await verifyDismiss(() async {
        await tester.tap(find.text('Take Photo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.binding.handlePopRoute();
      });
      await verifyDismiss(() async {
        await tester.tap(find.text('Choose from Photos'));
      });
    },
  );

  testWidgets(
    'repeated photo source dismissal does not accumulate layout changes',
    (tester) async {
      final series = testShelfSeries(id: 's1', name: 'Dimoo One');
      await pumpScreen(
        tester,
        CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
      );
      final before = collectionGeometry(tester);

      await tester.tap(find.byKey(const Key('collection_header_add_series')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byKey(const Key('catalog-photo-action')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expectCollectionGeometryUnchanged(tester, before);
      }
      await closeAddSeriesSheet(tester);
      expectCollectionGeometryUnchanged(tester, before);
    },
  );

  testWidgets(
    'clearing stale viewInsets restores Summary above segment without overlay',
    (tester) async {
      final series = testShelfSeries(id: 's1', name: 'Dimoo One');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _SegmentTestCollectionNotifier(
                CollectionSnapshot(
                  shelfSeries: [series],
                  figureStates: const {},
                ),
              ),
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
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 800),
                viewInsets: EdgeInsets.only(bottom: 280),
              ),
              child: const CollectionScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Simulate modal/camera dismiss restoring a zero inset viewport.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _SegmentTestCollectionNotifier(
                CollectionSnapshot(
                  shelfSeries: [series],
                  figureStates: const {},
                ),
              ),
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
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: const CollectionScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final after = collectionGeometry(tester);
      expect(after.viewInsets, EdgeInsets.zero);
      expect(after.summary.bottom, lessThanOrEqualTo(after.segment.top));
      expect(find.byKey(const Key('catalog-photo-confirmation')), findsNothing);
      expect(find.byKey(const Key('photo-source-sheet')), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );
}
