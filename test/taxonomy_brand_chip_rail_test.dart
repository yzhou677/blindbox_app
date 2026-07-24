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
}
