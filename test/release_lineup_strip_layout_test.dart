import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/release_lineup_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Common phone logical size (Pixel / iPhone-class width).
const Size _phoneSize = Size(390, 844);

List<ReleaseLineupSlot> _moodForecastLineup() {
  return const [
    ReleaseLineupSlot(
      slotId: 'dimoo_mood_radiant_rainbow',
      name: 'Radiant Rainbow',
      imageKey: 'dimoo_mood_radiant_rainbow',
      isSecret: false,
    ),
    ReleaseLineupSlot(
      slotId: 'dimoo_mood_cerulean_sky',
      name: 'Cerulean Sky',
      imageKey: 'dimoo_mood_cerulean_sky',
      isSecret: false,
    ),
    ReleaseLineupSlot(
      slotId: 'dimoo_mood_secret',
      name: 'Hidden Cloud',
      imageKey: 'dimoo_mood_secret',
      isSecret: true,
    ),
  ];
}

Future<void> _pumpStrip(
  WidgetTester tester, {
  required TextScaler textScaler,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _phoneSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: _phoneSize).copyWith(
          textScaler: textScaler,
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ReleaseLineupStrip(
              slots: _moodForecastLineup(),
              accent: const Color(0xFF7BA3C9),
              onSlotTap: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'phone size + textScaler 1.3: figure strip has no bottom overflow',
    (tester) async {
      final overflows = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflows.add(details);
        }
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      const scaler = TextScaler.linear(1.3);
      await _pumpStrip(tester, textScaler: scaler);

      expect(find.byType(ReleaseLineupStrip), findsOneWidget);
      expect(find.text('Radiant Rainbow'), findsOneWidget);
      expect(overflows, isEmpty, reason: 'BOTTOM OVERFLOWED under lineup strip');
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ReleaseLineupStrip)).height,
        ReleaseLineupStrip.stripHeightFor(scaler),
      );
    },
  );

  test('stripHeightFor adds slack over the old tight cellExtent+32 budget', () {
    expect(
      ReleaseLineupStrip.stripHeightFor(),
      greaterThan(ReleaseLineupStrip.cellExtent + 32),
    );
    expect(
      ReleaseLineupStrip.stripHeightFor(const TextScaler.linear(1.3)),
      greaterThan(ReleaseLineupStrip.stripHeightFor()),
    );
  });
}
