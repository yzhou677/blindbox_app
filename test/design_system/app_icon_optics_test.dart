import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/shared/widgets/catalog_quick_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  group('AppIconSizes ladder', () {
    test('hierarchy stays ordered', () {
      expect(AppIconSizes.metadata, lessThan(AppIconSizes.toolbar));
      expect(AppIconSizes.toolbar, lessThanOrEqualTo(AppIconSizes.standard));
      expect(AppIconSizes.standard, lessThanOrEqualTo(AppIconSizes.navigation));
      expect(AppIconSizes.cta, AppIconSizes.standard);
      expect(AppIconSizes.emptyHero, inInclusiveRange(72, 84));
      expect(AppIconSizes.headerQuiet, lessThan(AppIconSizes.toolbar));
      expect(AppIconSizes.secondaryShare, lessThan(AppIconSizes.toolbar));
    });
  });

  test('AppBar chrome tokens stay stable', () {
    expect(AppIconPadding.buttonMin, const Size(40, 40));
    expect(AppIconSizes.navigation, 24);
    expect(AppIconSizes.metadata, 18);
  });

  testWidgets('quick action uses shared size and fill axis', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogQuickActionButton(
            tooltip: 'Wishlist',
            icon: Symbols.favorite_rounded,
            active: true,
            filled: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded));
    expect(icon.size, AppIconSizes.quickAction);
    expect(icon.fill, ShelfySymbols.fillSolid);
    expect(
      tester.getSize(find.byType(CatalogQuickActionButton)),
      const Size(40, 40),
    );
  });

  testWidgets('quick action outline when not filled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogQuickActionButton(
            tooltip: 'Wishlist',
            icon: Symbols.favorite_rounded,
            onPressed: () {},
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded));
    expect(icon.fill, ShelfySymbols.fillOutline);
    expect(icon.size, AppIconSizes.quickAction);
  });
}
