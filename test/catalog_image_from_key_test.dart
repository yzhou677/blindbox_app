import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';

import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';



void main() {

  group('CatalogImageResolveCoordinator', () {

    test('ignores stale async generations', () {

      final coordinator = CatalogImageResolveCoordinator();

      final first = coordinator.begin();

      final second = coordinator.begin();



      expect(coordinator.shouldApply(first), isFalse);

      expect(coordinator.shouldApply(second), isTrue);

    });

  });



  group('catalogImageResolveFrameWaits', () {
    test('batch 0 waits one frame', () {
      expect(catalogImageResolveFrameWaits(0), 1);
    });

    test('batch 1 waits two frames', () {
      expect(catalogImageResolveFrameWaits(1), 2);
    });

    test('batch 2 waits three frames', () {
      expect(catalogImageResolveFrameWaits(2), 3);
    });
  });

  group('scheduleCatalogImageResolveAfterFrames', () {
    testWidgets('invokes onReady after one frame for batch 0', (tester) async {
      var readyCount = 0;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      scheduleCatalogImageResolveAfterFrames(
        staggerBatch: 0,
        isMounted: () => true,
        onReady: () => readyCount++,
      );

      expect(readyCount, 0);
      await tester.pump();
      expect(readyCount, 1);
    });
  });

  group('catalogImageWidgetKey', () {
    test('includes identity and imageKey for list stability', () {
      final key = catalogImageWidgetKey(
        displayMode: CatalogImageDisplayMode.seriesCoverThumb,
        imageKey: 'skullpanda_series_a',
        identity: 'skullpanda_series_a',
      );
      expect(key, isA<ValueKey<String>>());
      expect((key as ValueKey<String>).value, contains('skullpanda_series_a'));
    });
  });
}


