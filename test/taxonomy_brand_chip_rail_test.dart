import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact chip rail uses shorter height than default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TaxonomyBrandChipRail(
                options: const [
                  (id: 'a', label: 'All'),
                  (id: 'b', label: 'POP MART'),
                ],
                selectedId: 'a',
                onSelected: (_) {},
              ),
              TaxonomyBrandChipRail(
                key: const Key('compact_chip_rail'),
                options: const [
                  (id: 'a', label: 'All'),
                  (id: 'b', label: 'POP MART'),
                ],
                selectedId: 'a',
                onSelected: (_) {},
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );

    final defaultSize = tester.getSize(
      find.byType(TaxonomyBrandChipRail).at(0),
    );
    final compactSize = tester.getSize(
      find.byKey(const Key('compact_chip_rail')),
    );

    expect(defaultSize.height, 40);
    expect(compactSize.height, 36);
    expect(compactSize.height, lessThan(defaultSize.height));
  });

  testWidgets(
    'TaxonomyFilterPillChip selected and unselected match rail chip treatment',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                return Column(
                  children: [
                    TaxonomyBrandChipRail(
                      options: const [
                        (id: 'all', label: 'All Brands'),
                        (id: 'other', label: 'Other'),
                      ],
                      selectedId: 'all',
                      onSelected: (_) {},
                      compact: true,
                    ),
                    TaxonomyFilterPillChip(
                      key: const Key('duplicates_selected'),
                      label: 'Has Duplicates',
                      selected: true,
                      compact: true,
                      onTap: () {},
                    ),
                    TaxonomyFilterPillChip(
                      key: const Key('duplicates_unselected'),
                      label: 'Has Duplicates',
                      selected: false,
                      compact: true,
                      onTap: () {},
                    ),
                    ColoredBox(
                      key: const Key('expected_selected_fill'),
                      color: scheme.primaryContainer.withValues(alpha: 0.72),
                    ),
                    ColoredBox(
                      key: const Key('expected_unselected_fill'),
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.42,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      Color fillOf(Finder chipFinder) {
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: chipFinder,
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      final selectedFill = fillOf(find.byKey(const Key('duplicates_selected')));
      final unselectedFill = fillOf(
        find.byKey(const Key('duplicates_unselected')),
      );
      final brandSelectedFill = fillOf(
        find.ancestor(
          of: find.text('All Brands'),
          matching: find.byType(TaxonomyFilterPillChip),
        ),
      );

      expect(selectedFill, brandSelectedFill);
      expect(
        selectedFill,
        tester
            .widget<ColoredBox>(find.byKey(const Key('expected_selected_fill')))
            .color,
      );
      expect(
        unselectedFill,
        tester
            .widget<ColoredBox>(
              find.byKey(const Key('expected_unselected_fill')),
            )
            .color,
      );
      expect(selectedFill, isNot(equals(unselectedFill)));

      // Toggle path stays interactive.
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TaxonomyFilterPillChip(
              key: const Key('duplicates_toggle'),
              label: 'Has Duplicates',
              selected: false,
              compact: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('duplicates_toggle')));
      expect(tapped, isTrue);
    },
  );
}
