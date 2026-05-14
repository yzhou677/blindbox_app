import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typing updates query without entering search results mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('lab');
    final s1 = container.read(marketBrowseNotifierProvider);
    expect(s1.query, 'lab');
    expect(s1.searchResultsActive, false);

    n.submitSearch();
    final s2 = container.read(marketBrowseNotifierProvider);
    expect(s2.searchResultsActive, true);
  });

  test('clearing query exits search results mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('x');
    n.submitSearch();
    expect(container.read(marketBrowseNotifierProvider).searchResultsActive, true);

    n.setQuery('');
    final s = container.read(marketBrowseNotifierProvider);
    expect(s.query, '');
    expect(s.searchResultsActive, false);
  });

  test('submitSearch with blank query does not activate immersive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('   ');
    n.submitSearch();
    expect(container.read(marketBrowseNotifierProvider).searchResultsActive, false);
  });

  test('clearSearchSession clears query and exits immersive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('labubu');
    n.submitSearch();
    expect(container.read(marketBrowseNotifierProvider).searchResultsActive, true);

    n.clearSearchSession();
    final s = container.read(marketBrowseNotifierProvider);
    expect(s.query, '');
    expect(s.searchResultsActive, false);
  });
}
