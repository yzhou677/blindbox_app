import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_filter_section_label.dart';
import 'package:flutter/material.dart';

/// Brand taxonomy rail; optional IP rail when a brand is selected.
class MarketDiscoveryChips extends StatelessWidget {
  const MarketDiscoveryChips({
    super.key,
    required this.brandOptions,
    required this.ipOptions,
    required this.brandId,
    required this.ipId,
    required this.showIpRail,
    required this.onBrandSelected,
    required this.onIpSelected,
  });

  final List<({String id, String label})> brandOptions;
  final List<({String id, String label})> ipOptions;
  final String brandId;
  final String ipId;
  final bool showIpRail;
  final ValueChanged<String> onBrandSelected;
  final ValueChanged<String> onIpSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TaxonomyFilterSectionLabel(text: 'Brand'),
          const SizedBox(height: 6),
          TaxonomyBrandChipRail(
            options: brandOptions,
            selectedId: brandId,
            onSelected: onBrandSelected,
          ),
          if (showIpRail) ...[
            const SizedBox(height: 14),
            const TaxonomyFilterSectionLabel(text: 'IP'),
            const SizedBox(height: 6),
            TaxonomyBrandChipRail(
              options: ipOptions,
              selectedId: ipId,
              onSelected: onIpSelected,
            ),
          ],
        ],
      ),
    );
  }
}
