import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Local Shelf / Insights switch for the Collection page.
enum CollectionPageSegment { shelf, insights }

/// Material 3 segmented control for Collection page sections.
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
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<CollectionPageSegment>(
          segments: const [
            ButtonSegment<CollectionPageSegment>(
              value: CollectionPageSegment.shelf,
              label: Text('Shelf'),
              icon: Icon(Icons.grid_view_rounded, size: 18),
            ),
            ButtonSegment<CollectionPageSegment>(
              value: CollectionPageSegment.insights,
              label: Text('Insights'),
              icon: Icon(Icons.auto_awesome_rounded, size: 18),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (next) {
            if (next.isEmpty) return;
            onChanged(next.first);
          },
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
