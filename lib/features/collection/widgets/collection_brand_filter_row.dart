import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';

/// Shelf-side brand pills: **All** + known taxonomy brands (no IP / search).
class CollectionBrandFilterRow extends StatelessWidget {
  const CollectionBrandFilterRow({
    super.key,
    required this.selectedBrandId,
    required this.onBrandSelected,
  });

  final String selectedBrandId;
  final ValueChanged<String> onBrandSelected;

  static List<({String id, String label})> chipOptions() => [
        (id: MarketTaxonomyIds.anyBrand, label: 'All'),
        for (final b in MarketTaxonomy.brands) (id: b.id, label: b.displayLabel),
      ];

  @override
  Widget build(BuildContext context) {
    return TaxonomyBrandChipRail(
      options: chipOptions(),
      selectedId: selectedBrandId,
      onSelected: onBrandSelected,
      horizontalPadding: 20,
      height: 40,
      separatorWidth: 8,
    );
  }
}
