import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typing activates live search', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('lab');
    final s = container.read(marketBrowseNotifierProvider);
    expect(s.query, 'lab');
    expect(s.searchResultsActive, true);
  });

  test('clearing query exits search results mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('x');
    expect(container.read(marketBrowseNotifierProvider).searchResultsActive, true);

    n.setQuery('');
    final s = container.read(marketBrowseNotifierProvider);
    expect(s.query, '');
    expect(s.searchResultsActive, false);
  });

  test('clearSearchSession clears query and exits search mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(marketBrowseNotifierProvider.notifier);

    n.setQuery('labubu');
    expect(container.read(marketBrowseNotifierProvider).searchResultsActive, true);

    n.clearSearchSession();
    final s = container.read(marketBrowseNotifierProvider);
    expect(s.query, '');
    expect(s.searchResultsActive, false);
  });
}
