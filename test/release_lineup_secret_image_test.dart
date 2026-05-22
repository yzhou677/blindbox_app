import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/release_lineup_strip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secret with imageKey uses catalog art, not blur placeholder', () {
    const withArt = ReleaseLineupSlot(
      slotId: 'secret_fig',
      name: 'Hidden',
      imageKey: 'secret_fig',
      isSecret: true,
    );
    expect(ReleaseLineupStrip.slotUsesSecretPlaceholder(withArt), isFalse);
  });

  test('secret without imageKey uses blur placeholder', () {
    const noArt = ReleaseLineupSlot(
      slotId: 'secret_fig',
      name: 'Hidden',
      imageKey: '',
      isSecret: true,
    );
    expect(ReleaseLineupStrip.slotUsesSecretPlaceholder(noArt), isTrue);
  });
}
