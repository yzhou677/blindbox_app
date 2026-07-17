import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/widgets/shelfy_segmented_control.dart';
import 'package:flutter/material.dart';

/// Local Shelf / Insights / Wishlist switch for the Collection page.
enum CollectionPageSegment { shelf, insights, wishlist }

/// Collection-page chrome around [ShelfySegmentedControl].
class CollectionPageSegmentControl extends StatelessWidget {
  const CollectionPageSegmentControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CollectionPageSegment selected;
  final ValueChanged<CollectionPageSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        FeedRhythm.collectionSummaryToSegmentGap,
        AppSpacing.pageHorizontal,
        FeedRhythm.collectionSegmentToShelfHeader,
      ),
      child: ShelfySegmentedControl<CollectionPageSegment>(
        value: selected,
        onChanged: onChanged,
        segments: const [
          ShelfySegment(
            value: CollectionPageSegment.shelf,
            label: 'Shelf',
            icon: Icons.grid_view_rounded,
          ),
          ShelfySegment(
            value: CollectionPageSegment.insights,
            label: 'Insights',
            icon: Icons.auto_awesome_rounded,
          ),
          ShelfySegment(
            value: CollectionPageSegment.wishlist,
            label: 'Wishlist',
            icon: Icons.favorite_border_rounded,
          ),
        ],
      ),
    );
  }
}
