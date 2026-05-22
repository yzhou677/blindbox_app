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
}
