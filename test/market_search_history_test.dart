import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_section.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_storage.dart';
import 'package:blindbox_app/features/catalog/search/suggested_searches.dart';
import 'package:blindbox_app/features/market/search/market_search_history_provider.dart';
import 'package:blindbox_app/features/market/search/market_search_history_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('market history uses separate prefs key from catalog', () async {
    await SearchHistoryPrefsStorage.save(
      kCatalogSearchHistoryPrefsKey,
      ['Labubu'],
    );
    await MarketSearchHistoryStorage.save(['Skullpanda']);

    expect(await MarketSearchHistoryStorage.load(), ['Skullpanda']);
    expect(
      await SearchHistoryPrefsStorage.load(kCatalogSearchHistoryPrefsKey),
      ['Labubu'],
    );
  });

  test('market notifier add persists independently', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(marketSearchHistoryProvider.notifier).add('Crybaby');
    await Future<void>.delayed(Duration.zero);

    expect(await MarketSearchHistoryStorage.load(), ['crybaby']);
    expect(
      await SearchHistoryPrefsStorage.load(kCatalogSearchHistoryPrefsKey),
      isEmpty,
    );
  });

  testWidgets('market search reuses shared kSuggestedSearches when history empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: searchEmptyQuerySection(
            history: const [],
            onHistoryTap: (_) {},
            onRemove: (_) {},
            onClearAll: () {},
            onSuggestedTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Suggested Searches'), findsOneWidget);

    final poolQueries = kSuggestedSearches.map((s) => s.query).toSet();
    final displayed = kSuggestedSearches
        .where((s) => find.text(s.displayLabel).evaluate().isNotEmpty)
        .toList();
    expect(displayed.length, kSuggestedSearchesDisplayCount);
    for (final suggestion in displayed) {
      expect(poolQueries, contains(suggestion.query));
    }
  });
}
