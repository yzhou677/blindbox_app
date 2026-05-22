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
}
