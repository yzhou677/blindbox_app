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

final class _DefaultShelfUiPrefsNotifier extends CollectionShelfUiPrefsNotifier {
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
      CollectionSnapshot(
        shelfSeries: [series],
        figureStates: const {},
      ),
    );

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text(CollectorTypeCopy.screenTitle), findsWidgets);
    expect(find.text(CollectorTypeCopy.revealButton), findsOneWidget);
    expect(find.text(CollectorTypeCopy.journeyTitle), findsOneWidget);
    expect(find.text('Add series'), findsNothing);
    // Summary stays above the segment on both tabs.
    expect(
      find.byKey(const Key('collection_insights_compact_glance')),
      findsOneWidget,
    );
  });

  testWidgets('header order keeps summary above Shelf Insights segment', (
    tester,
  ) async {
    final series = testShelfSeries(id: 's1', name: 'Dimoo One');
    await pumpScreen(
      tester,
      CollectionSnapshot(
        shelfSeries: [series],
        figureStates: const {},
      ),
    );

    final searchY = tester.getTopLeft(find.byType(AppSearchField)).dy;
    final summaryY = tester
        .getTopLeft(find.byKey(const Key('collection_insights_compact_glance')))
        .dy;
    final segmentY =
        tester.getTopLeft(find.byType(CollectionPageSegmentControl)).dy;
    final addSeriesY = tester.getTopLeft(find.text('Add series')).dy;

    expect(searchY, lessThan(summaryY));
    expect(summaryY, lessThan(segmentY));
    expect(segmentY, lessThan(addSeriesY));
  });
}
