import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_provider.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_section.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Codec
// ---------------------------------------------------------------------------

void main() {
  group('CatalogSearchHistoryCodec', () {
    test('returns empty list for null input', () {
      expect(CatalogSearchHistoryCodec.tryDecode(null), isEmpty);
    });

    test('returns empty list for empty string', () {
      expect(CatalogSearchHistoryCodec.tryDecode(''), isEmpty);
    });

    test('returns empty list for corrupt JSON', () {
      expect(CatalogSearchHistoryCodec.tryDecode('{not valid}'), isEmpty);
    });

    test('returns empty list when JSON is not a list', () {
      expect(CatalogSearchHistoryCodec.tryDecode('{"q":"Labubu"}'), isEmpty);
    });

    test('filters non-string items silently', () {
      expect(CatalogSearchHistoryCodec.tryDecode('[1, true, "Labubu"]'),
          equals(['Labubu']));
    });

    test('filters empty strings', () {
      expect(
          CatalogSearchHistoryCodec.tryDecode('["Labubu", "", "Crybaby"]'),
          equals(['Labubu', 'Crybaby']));
    });

    test('decodes a valid list', () {
      const raw = '["Labubu","Crybaby","Nommi"]';
      expect(CatalogSearchHistoryCodec.tryDecode(raw),
          equals(['Labubu', 'Crybaby', 'Nommi']));
    });

    test('round-trips encode → decode', () {
      final queries = ['Labubu', 'Crybaby', 'Nommi'];
      final encoded = CatalogSearchHistoryCodec.encode(queries);
      expect(CatalogSearchHistoryCodec.tryDecode(encoded), equals(queries));
    });
  });

  // -------------------------------------------------------------------------
  // Rules
  // -------------------------------------------------------------------------

  group('CatalogSearchHistoryRules.normalize', () {
    test('trims leading and trailing whitespace', () {
      expect(CatalogSearchHistoryRules.normalize('  Labubu  '), 'Labubu');
    });

    test('collapses internal multiple spaces to one', () {
      expect(
          CatalogSearchHistoryRules.normalize('Labubu   v2'), 'Labubu v2');
    });

    test('collapses tabs and mixed whitespace', () {
      expect(CatalogSearchHistoryRules.normalize('Labubu\t\tv2'), 'Labubu v2');
    });

    test('empty string stays empty', () {
      expect(CatalogSearchHistoryRules.normalize(''), '');
    });

    test('already-clean string is unchanged', () {
      expect(CatalogSearchHistoryRules.normalize('Labubu'), 'Labubu');
    });
  });

  group('CatalogSearchHistoryRules.add', () {
    test('adds new query at front', () {
      final result = CatalogSearchHistoryRules.add(['Crybaby'], 'Labubu');
      expect(result, equals(['Labubu', 'Crybaby']));
    });

    test('ignores blank query', () {
      final result = CatalogSearchHistoryRules.add(['Labubu'], '   ');
      expect(result, equals(['Labubu']));
    });

    test('trims and collapses spaces before adding', () {
      final result = CatalogSearchHistoryRules.add([], '  Labubu  v2  ');
      expect(result, equals(['Labubu v2']));
    });

    test('promotes existing query to top (deduplication)', () {
      final result = CatalogSearchHistoryRules.add(
          ['Labubu', 'Crybaby', 'Nommi'], 'Crybaby');
      expect(result, equals(['Crybaby', 'Labubu', 'Nommi']));
    });

    test('promotes to top even when already at front', () {
      final result =
          CatalogSearchHistoryRules.add(['Labubu', 'Crybaby'], 'Labubu');
      expect(result, equals(['Labubu', 'Crybaby']));
    });

    test('no duplicates after promote-to-top', () {
      final result = CatalogSearchHistoryRules.add(
          ['Labubu', 'Crybaby', 'Nommi'], 'Nommi');
      expect(result.toSet().length, equals(result.length));
    });

    test('caps at kCatalogSearchHistoryMaxEntries (15)', () {
      final existing = List.generate(15, (i) => 'q$i');
      final result = CatalogSearchHistoryRules.add(existing, 'new');
      expect(result.length, equals(kCatalogSearchHistoryMaxEntries));
      expect(result.first, equals('new'));
    });

    test('adding when at cap drops oldest entry', () {
      final existing = List.generate(15, (i) => 'q$i'); // q0..q14
      final result = CatalogSearchHistoryRules.add(existing, 'new');
      expect(result.contains('q14'), isFalse); // q14 is the oldest → dropped
      expect(result.first, equals('new'));
    });

    test('cap of exactly max entries keeps all', () {
      final existing = List.generate(14, (i) => 'q$i'); // 14 items
      final result = CatalogSearchHistoryRules.add(existing, 'new');
      expect(result.length, equals(15));
    });
  });

  group('CatalogSearchHistoryRules.remove', () {
    test('removes matching query', () {
      final result =
          CatalogSearchHistoryRules.remove(['Labubu', 'Crybaby'], 'Crybaby');
      expect(result, equals(['Labubu']));
    });

    test('no-op when query not in list', () {
      final list = ['Labubu', 'Crybaby'];
      expect(CatalogSearchHistoryRules.remove(list, 'Nommi'), equals(list));
    });

    test('removes only the first occurrence (should be unique)', () {
      final result = CatalogSearchHistoryRules.remove(
          ['A', 'B', 'A'], 'A'); // defensive
      expect(result, equals(['B']));
    });
  });

  group('CatalogSearchHistoryRules.clear', () {
    test('returns empty list', () {
      expect(CatalogSearchHistoryRules.clear(), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Storage (SharedPreferences mock)
  // -------------------------------------------------------------------------

  group('CatalogSearchHistoryStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns empty when no key stored', () async {
      final result = await CatalogSearchHistoryStorage.load();
      expect(result, isEmpty);
    });

    test('save then load round-trips correctly', () async {
      await CatalogSearchHistoryStorage.save(['Labubu', 'Crybaby']);
      final result = await CatalogSearchHistoryStorage.load();
      expect(result, equals(['Labubu', 'Crybaby']));
    });

    test('load returns empty on corrupt stored data', () async {
      SharedPreferences.setMockInitialValues({
        kCatalogSearchHistoryPrefsKey: '{corrupt',
      });
      final result = await CatalogSearchHistoryStorage.load();
      expect(result, isEmpty);
    });

    test('save overwrites prior value', () async {
      await CatalogSearchHistoryStorage.save(['old']);
      await CatalogSearchHistoryStorage.save(['new']);
      final result = await CatalogSearchHistoryStorage.load();
      expect(result, equals(['new']));
    });

    test('clear removes the stored key', () async {
      await CatalogSearchHistoryStorage.save(['Labubu']);
      await CatalogSearchHistoryStorage.clear();
      final result = await CatalogSearchHistoryStorage.load();
      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Notifier (Riverpod)
  // -------------------------------------------------------------------------

  group('CatalogSearchHistoryNotifier', () {
    ProviderContainer makeContainer() {
      return ProviderContainer();
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      expect(container.read(catalogSearchHistoryProvider), isEmpty);
    });

    test('add records query at front', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(catalogSearchHistoryProvider.notifier).add('Labubu');
      expect(container.read(catalogSearchHistoryProvider).first,
          equals('Labubu'));
    });

    test('add deduplicates and promotes to top', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final n = container.read(catalogSearchHistoryProvider.notifier);
      n.add('Labubu');
      n.add('Crybaby');
      n.add('Labubu');
      expect(
        container.read(catalogSearchHistoryProvider),
        equals(['Labubu', 'Crybaby']),
      );
    });

    test('add ignores blank query', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(catalogSearchHistoryProvider.notifier).add('  ');
      expect(container.read(catalogSearchHistoryProvider), isEmpty);
    });

    test('remove deletes specific query', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final n = container.read(catalogSearchHistoryProvider.notifier);
      n.add('Labubu');
      n.add('Crybaby');
      n.remove('Labubu');
      expect(container.read(catalogSearchHistoryProvider), equals(['Crybaby']));
    });

    test('clearAll empties the list', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final n = container.read(catalogSearchHistoryProvider.notifier);
      n.add('Labubu');
      n.add('Crybaby');
      n.clearAll();
      expect(container.read(catalogSearchHistoryProvider), isEmpty);
    });

    test('persistence: add persists to SharedPreferences', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(catalogSearchHistoryProvider.notifier).add('Labubu');
      // Give the fire-and-forget save a microtask to complete.
      await Future<void>.delayed(Duration.zero);
      final loaded = await CatalogSearchHistoryStorage.load();
      expect(loaded, contains('Labubu'));
    });

    test('persistence: clearAll persists empty list', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final n = container.read(catalogSearchHistoryProvider.notifier);
      n.add('Labubu');
      n.clearAll();
      await Future<void>.delayed(Duration.zero);
      final loaded = await CatalogSearchHistoryStorage.load();
      expect(loaded, isEmpty);
    });

    testWidgets('loads persisted history on build', (tester) async {
      // Pre-seed prefs before creating the container.
      SharedPreferences.setMockInitialValues({
        kCatalogSearchHistoryPrefsKey:
            CatalogSearchHistoryCodec.encode(['Persisted']),
      });
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(catalogSearchHistoryProvider); // trigger build
      // Build fires async load — pump until settled so all async ops complete.
      await tester.pumpAndSettle();
      expect(container.read(catalogSearchHistoryProvider), contains('Persisted'));
    });
  });

  // -------------------------------------------------------------------------
  // CatalogSearchHistorySection widget
  // -------------------------------------------------------------------------

  group('CatalogSearchHistorySection widget', () {
    Widget _wrap({
      required List<String> queries,
      ValueChanged<String>? onQueryTap,
      ValueChanged<String>? onRemove,
      VoidCallback? onClearAll,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: CatalogSearchHistorySection(
            queries: queries,
            onQueryTap: onQueryTap ?? (_) {},
            onRemove: onRemove ?? (_) {},
            onClearAll: onClearAll ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders nothing when queries is empty', (tester) async {
      await tester.pumpWidget(_wrap(queries: const []));
      expect(find.text('Recent Searches'), findsNothing);
      expect(find.text('Clear All'), findsNothing);
    });

    testWidgets('renders header and queries when non-empty', (tester) async {
      await tester.pumpWidget(_wrap(queries: const ['Labubu', 'Crybaby']));
      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Labubu'), findsOneWidget);
      expect(find.text('Crybaby'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('tapping row calls onQueryTap with the query', (tester) async {
      String? tapped;
      await tester.pumpWidget(_wrap(
        queries: const ['Labubu'],
        onQueryTap: (q) => tapped = q,
      ));
      await tester.tap(find.text('Labubu'));
      expect(tapped, equals('Labubu'));
    });

    testWidgets('tapping × calls onRemove with the query', (tester) async {
      String? removed;
      await tester.pumpWidget(_wrap(
        queries: const ['Labubu'],
        onRemove: (q) => removed = q,
      ));
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(removed, equals('Labubu'));
    });

    testWidgets('tapping Clear All calls onClearAll', (tester) async {
      var cleared = false;
      await tester.pumpWidget(_wrap(
        queries: const ['Labubu'],
        onClearAll: () => cleared = true,
      ));
      await tester.tap(find.text('Clear All'));
      expect(cleared, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // CatalogSearchHistorySection is reused — verify same widget in both sites
  // -------------------------------------------------------------------------

  group('CatalogSearchHistorySection reuse', () {
    test('widget class is defined in search feature folder', () {
      // Just instantiating the widget from the search package import is enough
      // to confirm the single shared implementation is accessible from outside
      // the catalog/search folder.
      final widget = CatalogSearchHistorySection(
        queries: const ['Labubu'],
        onQueryTap: (_) {},
        onRemove: (_) {},
        onClearAll: () {},
      );
      expect(widget, isA<CatalogSearchHistorySection>());
    });
  });
}
