import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SeriesHeroMetaBlock hides duplicate brand when IP matches', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SeriesHeroMetaBlock(
            brand: 'POP MART',
            ipLine: 'POP MART',
            trailingMeta: '3 listings',
            density: SeriesHeroMetaDensity.compact,
          ),
        ),
      ),
    );

    expect(find.text('POP MART'), findsOneWidget);
    expect(find.text('3 listings'), findsOneWidget);
  });

  testWidgets('ipNameTrailing sits beside the IP glyphs, not at row end', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: SeriesHeroMetaBlock(
              brand: 'POP MART',
              ipLine: 'SKULLPANDA',
              ipNameTrailing: const SizedBox(
                key: Key('ip_trailing_probe'),
                width: 18,
                height: 18,
              ),
            ),
          ),
        ),
      ),
    );

    final ipRight = tester.getBottomRight(find.text('SKULLPANDA')).dx;
    final trailingLeft = tester
        .getTopLeft(find.byKey(const Key('ip_trailing_probe')))
        .dx;
    expect(trailingLeft - ipRight, lessThan(8));
    expect(trailingLeft, greaterThanOrEqualTo(ipRight));
  });
}
