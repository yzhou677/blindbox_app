import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/shared/widgets/bling_heart_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  testWidgets(
    'keeps the empty-hero heart recipe and static CustomPaint layers',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: BlingHeartEmptyState())),
        ),
      );

      final heart = find.byKey(const Key('wishlist_empty_heart_icon'));
      final icon = tester.widget<Icon>(heart);
      expect(icon.icon, Symbols.favorite_rounded);
      expect(icon.size, AppIconSizes.emptyHero);
      expect(icon.fill, ShelfySymbols.fillOutline);
      expect(icon.weight, ShelfySymbols.emptyStateWeight);
      expect(icon.opticalSize, ShelfySymbols.emptyStateOpticalSize);

      // Glow + sparkles — two static painters under the heart stack.
      expect(
        find.descendant(
          of: find.byType(BlingHeartEmptyState),
          matching: find.byType(CustomPaint),
        ),
        findsNWidgets(2),
      );
    },
  );
}
