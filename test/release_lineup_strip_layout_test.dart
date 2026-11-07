import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/release_lineup_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Common phone logical size (Pixel-class / iPhone-class width).
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
  List<ReleaseLineupSlot>? slots,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _phoneSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: _phoneSize,
        ).copyWith(textScaler: textScaler),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ReleaseLineupStrip(
              slots: slots ?? _moodForecastLineup(),
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
    'phone size + textScaler 1.3 does not overflow the horizontal figure strip',
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

      await _pumpStrip(
        tester,
        textScaler: const TextScaler.linear(1.3),
      );

      expect(find.byType(ReleaseLineupStrip), findsOneWidget);
      expect(find.text('Radiant Rainbow'), findsOneWidget);
      expect(find.text('Cerulean Sky'), findsOneWidget);
      expect(find.text('Secret'), findsOneWidget);

      expect(overflows, isEmpty, reason: 'RenderFlex / layout overflow');
      expect(tester.takeException(), isNull);

      final stripSize = tester.getSize(find.byType(ReleaseLineupStrip));
      final expected = ReleaseLineupStrip.stripHeightFor(
        tester.element(find.byType(ReleaseLineupStrip)),
      );
      expect(stripSize.height, expected);
      expect(
        stripSize.height,
        greaterThan(ReleaseLineupStrip.cellExtent + 32),
        reason: 'scaled label must grow strip past the old fixed budget',
      );
    },
  );

  testWidgets(
    'default text scale strip height matches live label metrics (no 1px shortfall)',
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

      await _pumpStrip(tester, textScaler: TextScaler.noScaling);

      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);

      final strip = find.byType(ReleaseLineupStrip);
      final height = tester.getSize(strip).height;
      final budget = ReleaseLineupStrip.cellExtent + 32;
      // Old fixed height was exactly tight / 1px short depending on font metrics.
      expect(height, greaterThanOrEqualTo(budget));
    },
  );
}
