import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';

/// Shelf-side IP pills from Collection shelf facets (brand-scoped).
class CollectionIpFilterRow extends StatelessWidget {
  const CollectionIpFilterRow({
    super.key,
    required this.options,
    required this.selectedIpId,
    required this.onIpSelected,
  });

  final List<CollectionIpFilterOption> options;
  final String selectedIpId;
  final ValueChanged<String> onIpSelected;

  @override
  Widget build(BuildContext context) {
    return TaxonomyBrandChipRail(
      options: options,
      selectedId: selectedIpId,
      onSelected: onIpSelected,
      horizontalPadding: 20,
      height: 40,
      separatorWidth: 8,
    );
  }
}
