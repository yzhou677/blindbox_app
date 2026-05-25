import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/utils/listing_description_text.dart';
import 'package:blindbox_app/features/market/widgets/expandable_description.dart';
import 'package:flutter/material.dart';

/// “About this listing” block with sanitized, expandable description copy.
class ListingDescriptionSection extends StatelessWidget {
  const ListingDescriptionSection({
    super.key,
    required this.description,
    this.sectionTitle = 'About this listing',
    this.collapsedMaxLines = 5,
  });

  final String? description;
  final String sectionTitle;
  final int collapsedMaxLines;

  @override
  Widget build(BuildContext context) {
    final sanitized = sanitizeListingDescription(description);
    if (sanitized == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
      height: 1.35,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: CollectibleTypography.figureMeta(textTheme, scheme).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 4),
          ExpandableDescription(
            text: sanitized,
            style: bodyStyle ?? const TextStyle(height: 1.35),
            collapsedMaxLines: collapsedMaxLines,
            backgroundColor: scheme.surface,
          ),
        ],
      ),
    );
  }
}
