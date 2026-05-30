import 'package:blindbox_app/features/market/application/market_browse_root_navigation.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('route path helpers', () {
    test('isMarketBrowseRootPath matches feed root only', () {
      expect(isMarketBrowseRootPath('/market'), isTrue);
      expect(isMarketBrowseRootPath('/market/search'), isFalse);
      expect(isMarketBrowseRootPath('/market/listing/abc'), isFalse);
    });

    test('isMarketSearchRoutePath matches search overlay', () {
      expect(isMarketSearchRoutePath('/market/search'), isTrue);
      expect(isMarketSearchRoutePath('/market'), isFalse);
      expect(isMarketSearchRoutePath('/market/listing/x'), isFalse);
    });
  });

  group('search overlay session reset', () {
    test('clearSession and setOpen(false) exit committed search', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(marketSearchBrowseNotifierProvider.notifier)
          .commitQuery('labubu');
      container.read(marketSearchOverlayOpenProvider.notifier).setOpen(true);

      container.read(marketSearchBrowseNotifierProvider.notifier).clearSession();
      container.read(marketSearchOverlayOpenProvider.notifier).setOpen(false);

      final search = container.read(marketSearchBrowseNotifierProvider);
      expect(search.isCommitted, isFalse);
      expect(search.query, isEmpty);
      expect(container.read(marketSearchOverlayOpenProvider), isFalse);
    });
  });
}
