import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _blindboxTestOverrides() => [
  homeFeedSnapshotProvider.overrideWith(
    (_) async => HomeFeedSnapshot(
      latest: mockSeriesReleases,
      trending: mockSeriesReleases.skip(1).take(4).toList(growable: false),
    ),
  ),
  seriesReleaseLookupProvider.overrideWithValue(mockSeriesReleaseByDropId),
];

final class EmptyTestCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('App shell shows Home tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Latest drops'), findsOneWidget);
    expect(find.text('Moon Mischief'), findsOneWidget);
    expect(find.text('Trending series'), findsOneWidget);
  });

  testWidgets('Collection tab shows series-first shelf and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('My collection'), findsWidgets);
    expect(find.text('In collection'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(
      find.byKey(const Key('collection_header_add_series')),
      findsOneWidget,
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('The Other One'), findsOneWidget);

    await tester.tap(find.text('Dreams Inc.'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('Nothing on your shelf for this brand yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('The Other One'), findsOneWidget);
  });

  testWidgets('Add series sheet dismisses when leaving Collection tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('collection_header_add_series')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsNothing);

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsNothing);
    expect(find.text('My collection'), findsWidgets);

    // Flush catalog background refresh timer started by Add sheet.
    await tester.pump(const Duration(seconds: 13));
  });

  testWidgets('Market tab shows search and browse filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Market'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Chasers'), findsNothing);
    expect(find.text('Collectibles'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    await tester.tap(find.text('POP MART'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('THE MONSTERS'), findsWidgets);
  });

  testWidgets('Collection empty state is polished', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            EmptyTestCollectionNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Empty shelf'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
