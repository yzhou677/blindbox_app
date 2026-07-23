import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery motion stays subtle', () {
    expect(CollectibleMotion.galleryEnterScale, greaterThan(0.98));
    expect(CollectibleMotion.galleryEnterScale, lessThan(1));
  });

  test('sheet animation style uses calm durations', () {
    final style = CollectibleMotion.sheetAnimationStyle();
    expect(style.duration, CollectibleMotion.sheet);
    expect(style.reverseDuration, CollectibleMotion.sheetDismiss);
  });

  test('finding checklist pacing is calm and ordered', () {
    final advances = CollectibleMotion.recognitionFindingChecklistAdvanceAt;
    expect(advances, hasLength(4));
    expect(
      advances[0],
      CollectibleMotion.recognitionFindingShapeComplete,
    );
    expect(
      advances[1],
      CollectibleMotion.recognitionFindingColorsComplete,
    );
    expect(
      advances[2],
      CollectibleMotion.recognitionFindingAccessoriesComplete,
    );
    expect(
      advances[3],
      CollectibleMotion.recognitionFindingFacialComplete,
    );
    expect(advances[0].inMilliseconds, 900);
    expect(advances[3].inMilliseconds, 4400);
    for (var i = 1; i < advances.length; i++) {
      expect(advances[i] > advances[i - 1], isTrue);
    }
    expect(
      CollectibleMotion.recognitionFindingNoMatchSettle.inMilliseconds,
      inInclusiveRange(400, 600),
    );
    expect(
      CollectibleMotion.recognitionFindingNoMatchChecklistOpacity,
      inInclusiveRange(0.55, 0.70),
    );
  });
}
