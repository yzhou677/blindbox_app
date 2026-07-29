import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_filters_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_layout_controls.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Filter sheet title shares sheetHorizontal inset with content', (
    tester,
  ) async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showCollectionShelfFiltersSheet(
                  context: context,
                  initial: CollectionShelfFilters.empty,
                  shelfSeries: snap.shelfSeries,
                  figureStates: snap.figureStates,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CollectibleSheetInsets), findsOneWidget);
    final title = tester.getTopLeft(
      find.text(CollectionVocabulary.filters).first,
    );
    final section = tester.getTopLeft(
      find.text(CollectionVocabulary.filterSectionProgress),
    );
    // Title and body share one left edge (not flush to the physical screen
    // edge — on wide test surfaces Material may also inset the sheet host).
    expect(title.dx, section.dx);
    expect(title.dx, greaterThan(0));

    final insetPadding = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byType(CollectibleSheetInsets),
            matching: find.byType(Padding),
          ),
        )
        .map((p) => p.padding.resolve(TextDirection.ltr))
        .firstWhere(
          (e) =>
              e.left == FeedRhythm.sheetHorizontal &&
              e.right == FeedRhythm.sheetHorizontal,
        );
    expect(insetPadding.left, FeedRhythm.sheetHorizontal);
  });

  testWidgets('Layout sheet title is inset from the screen edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showCollectionShelfLayoutSheet(
                  context: context,
                  selected: CollectionShelfLayout.grid,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CollectibleSheetInsets), findsOneWidget);
    final title = tester.getTopLeft(
      find.text(CollectionVocabulary.layoutMenuTitle),
    );
    expect(title.dx, greaterThan(0));

    final chrome = tester.getTopLeft(find.byType(CollectibleSheetChrome));
    expect(title.dx, chrome.dx);

    final row = find.byKey(const Key('collection_layout_option_grid'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
  });

  testWidgets('Filter chips wrap without overflow on a narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showCollectionShelfFiltersSheet(
                  context: context,
                  initial: CollectionShelfFilters.empty,
                  shelfSeries: snap.shelfSeries,
                  figureStates: snap.figureStates,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(CollectibleSheetChrome), findsOneWidget);
    expect(find.byKey(const Key('filters_sheet_show_results')), findsOneWidget);
  });
}
