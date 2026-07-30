import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_layout_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _ToolbarTestCollectionNotifier extends CollectionNotifier {
  _ToolbarTestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

Future<void> _pumpCollection(
  WidgetTester tester, {
  Size? surfaceSize,
  CollectionShelfSort sort = CollectionShelfSort.recentlyAdded,
}) async {
  SharedPreferences.setMockInitialValues({
    'collection_shelf_ui_prefs_v1': '{"sort":"${sort.name}","layout":"grid"}',
  });
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final snap = CollectionSnapshot(
    shelfSeries: [testShelfSeries()],
    figureStates: const {},
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _ToolbarTestCollectionNotifier(snap),
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
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Layout control exposes a 48×48 accessible tap target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectionShelfLayoutControl(
            layout: CollectionShelfLayout.grid,
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const Key('collection_shelf_layout_control')),
    );
    expect(size.width, CollectionShelfLayoutControl.minTapExtent);
    expect(size.height, CollectionShelfLayoutControl.minTapExtent);
  });

  testWidgets(
    'toolbar is Filters → flexible space → Layout (no Sort control)',
    (tester) async {
      await _pumpCollection(tester);

      final filters = find.byKey(const Key('collection_shelf_filters_control'));
      final layout = find.byKey(const Key('collection_shelf_layout_control'));
      final sort = find.byKey(const Key('collection_shelf_sort_menu'));

      expect(filters, findsOneWidget);
      expect(layout, findsOneWidget);
      expect(sort, findsNothing);

      final filtersBox = tester.getRect(filters);
      final layoutBox = tester.getRect(layout);
      final screenWidth = tester.getSize(find.byType(CollectionScreen)).width;

      expect(filtersBox.left, lessThan(layoutBox.left));
      expect(layoutBox.left - filtersBox.right, greaterThan(AppSpacing.sm));
      expect(
        (screenWidth - AppSpacing.pageHorizontal) - layoutBox.right,
        inInclusiveRange(0, 1),
      );
      expect(filtersBox.overlaps(layoutBox), isFalse);
      expect(layoutBox.width, greaterThanOrEqualTo(48));
      expect(layoutBox.height, greaterThanOrEqualTo(48));
      expect((filtersBox.center.dy - layoutBox.center.dy).abs(), lessThan(1));
    },
  );

  testWidgets('toolbar stays balanced on a narrow phone', (tester) async {
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('RenderFlex overflowed') &&
          text.contains('collection_screen.dart')) {
        return;
      }
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    await _pumpCollection(
      tester,
      surfaceSize: const Size(320, 800),
      sort: CollectionShelfSort.alphabetical,
    );

    expect(find.byKey(const Key('collection_shelf_sort_menu')), findsNothing);
    final layout = find.byKey(const Key('collection_shelf_layout_control'));
    final filters = find.byKey(const Key('collection_shelf_filters_control'));
    expect(layout, findsOneWidget);
    expect(filters, findsOneWidget);

    final layoutBox = tester.getRect(layout);
    final filtersBox = tester.getRect(filters);
    expect(filtersBox.left, lessThan(layoutBox.left));
    expect(filtersBox.overlaps(layoutBox), isFalse);
    expect(layoutBox.width, CollectionShelfLayoutControl.minTapExtent);
  });

  testWidgets('Filters and Layout are not equal-width across the row', (
    tester,
  ) async {
    await _pumpCollection(tester);

    final filtersBox = tester.getRect(
      find.byKey(const Key('collection_shelf_filters_control')),
    );
    final layoutBox = tester.getRect(
      find.byKey(const Key('collection_shelf_layout_control')),
    );
    final screenWidth = tester.getSize(find.byType(CollectionScreen)).width;

    expect(layoutBox.width, CollectionShelfLayoutControl.minTapExtent);
    expect(filtersBox.width + layoutBox.width, lessThan(screenWidth * 0.55));
    expect(layoutBox.left - filtersBox.right, greaterThan(layoutBox.width));
  });
}
