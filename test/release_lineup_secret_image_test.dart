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

  test('secret without imageKey or url uses blur placeholder', () {
    const noArt = ReleaseLineupSlot(
      slotId: 'secret_fig',
      name: 'Hidden',
      imageKey: '',
      isSecret: true,
    );
    expect(ReleaseLineupStrip.slotUsesSecretPlaceholder(noArt), isTrue);

    const mockUrl = ReleaseLineupSlot(
      slotId: 'eclipse',
      name: 'Eclipse',
      imageKey: '',
      imageUrl: 'https://example.com/eclipse.png',
      isSecret: true,
    );
    expect(ReleaseLineupStrip.slotUsesSecretPlaceholder(mockUrl), isFalse);
  });
}
