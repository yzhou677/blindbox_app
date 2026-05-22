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


