import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';

/// Shelf-side brand pills from Collection shelf facets.
class CollectionBrandFilterRow extends StatelessWidget {
  const CollectionBrandFilterRow({
    super.key,
    required this.options,
    required this.selectedBrandId,
    required this.onBrandSelected,
  });

  final List<CollectionBrandFilterOption> options;
  final String selectedBrandId;
  final ValueChanged<String> onBrandSelected;

  @override
  Widget build(BuildContext context) {
    return TaxonomyBrandChipRail(
      options: options,
      selectedId: selectedBrandId,
      onSelected: onBrandSelected,
      horizontalPadding: 20,
      height: 40,
      separatorWidth: 8,
    );
  }
}
