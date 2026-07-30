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
    'toolbar order is Filters → Sort → Layout with Layout rightmost',
    (tester) async {
      await _pumpCollection(tester);

      final filters = find.byKey(const Key('collection_shelf_filters_control'));
      final sort = find.byKey(const Key('collection_shelf_sort_menu'));
      final layout = find.byKey(const Key('collection_shelf_layout_control'));

      expect(filters, findsOneWidget);
      expect(sort, findsOneWidget);
      expect(layout, findsOneWidget);

      final filtersBox = tester.getRect(filters);
      final sortBox = tester.getRect(sort);
      final layoutBox = tester.getRect(layout);
      final screenWidth = tester.getSize(find.byType(CollectionScreen)).width;

      // Filters left; Sort then Layout as a right-aligned group.
      expect(filtersBox.left, lessThan(sortBox.left));
      expect(sortBox.left, lessThan(layoutBox.left));
      expect(layoutBox.right, greaterThan(sortBox.right));
      // Flexible space sits between Filters and the Sort/Layout group.
      expect(sortBox.left - filtersBox.right, greaterThan(AppSpacing.sm));

      // ~12dp shared-token gap between Sort and Layout hit targets.
      expect(layoutBox.left - sortBox.right, closeTo(AppSpacing.md, 0.5));

      // Layout aligns to the standard page trailing inset.
      expect(
        (screenWidth - AppSpacing.pageHorizontal) - layoutBox.right,
        inInclusiveRange(0, 1),
      );

      // Tap targets do not overlap.
      expect(filtersBox.overlaps(sortBox), isFalse);
      expect(sortBox.overlaps(layoutBox), isFalse);

      // Accessible targets.
      expect(sortBox.height, greaterThanOrEqualTo(48));
      expect(sortBox.width, greaterThanOrEqualTo(48));
      expect(layoutBox.width, greaterThanOrEqualTo(48));
      expect(layoutBox.height, greaterThanOrEqualTo(48));

      // Shared vertical centerline.
      expect((filtersBox.center.dy - layoutBox.center.dy).abs(), lessThan(1));
      expect((sortBox.center.dy - layoutBox.center.dy).abs(), lessThan(1));
    },
  );

  testWidgets('toolbar does not overflow on a narrow phone with a long sort', (
    tester,
  ) async {
    // Collection header trailing actions can overflow at 320dp independently of
    // this toolbar; swallow that known RenderFlex so we can assert toolbar geometry.
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

    final sort = find.byKey(const Key('collection_shelf_sort_menu'));
    final layout = find.byKey(const Key('collection_shelf_layout_control'));
    final filters = find.byKey(const Key('collection_shelf_filters_control'));

    expect(sort, findsOneWidget);
    expect(layout, findsOneWidget);
    expect(filters, findsOneWidget);

    final sortBox = tester.getRect(sort);
    final layoutBox = tester.getRect(layout);
    final filtersBox = tester.getRect(filters);

    expect(filtersBox.left, lessThan(sortBox.left));
    expect(sortBox.left, lessThan(layoutBox.left));
    expect(filtersBox.overlaps(sortBox), isFalse);
    expect(sortBox.overlaps(layoutBox), isFalse);
    expect(layoutBox.width, greaterThanOrEqualTo(48));
    expect(layoutBox.height, greaterThanOrEqualTo(48));
    expect(sortBox.height, greaterThanOrEqualTo(48));
    expect(sortBox.width, greaterThanOrEqualTo(48));
    expect(layoutBox.left - sortBox.right, closeTo(AppSpacing.md, 0.5));
    // Layout stays rightmost and keeps its full tap target.
    expect(layoutBox.width, CollectionShelfLayoutControl.minTapExtent);
  });

  testWidgets(
    'toolbar does not equal-width expand Sort and Layout across the row',
    (tester) async {
      await _pumpCollection(tester);

      final filters = find.byKey(const Key('collection_shelf_filters_control'));
      final layout = find.byKey(const Key('collection_shelf_layout_control'));
      final sort = find.byKey(const Key('collection_shelf_sort_menu'));

      final filtersBox = tester.getRect(filters);
      final layoutBox = tester.getRect(layout);
      final sortBox = tester.getRect(sort);
      final screenWidth = tester.getSize(find.byType(CollectionScreen)).width;

      // Right-side group stays compact — not three evenly spaced slots.
      final gapFiltersToSort = sortBox.left - filtersBox.right;
      final gapSortToLayout = layoutBox.left - sortBox.right;
      expect(gapFiltersToSort, greaterThan(gapSortToLayout * 3));

      // Layout remains a fixed 48×48 control, not a stretched Expanded child.
      expect(layoutBox.width, CollectionShelfLayoutControl.minTapExtent);
      expect(layoutBox.width + sortBox.width, lessThan(screenWidth * 0.55));
    },
  );
}
