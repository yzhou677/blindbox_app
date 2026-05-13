import 'package:blindbox_app/features/collection/widgets/collection_layout.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_card.dart';
import 'package:blindbox_app/models/owned_collectible.dart';
import 'package:flutter/material.dart';

/// Responsive sliver grid with stagger-friendly [appear] animations per cell.
class CollectionShelfGrid extends StatelessWidget {
  const CollectionShelfGrid({
    super.key,
    required this.items,
    required this.appearAnimations,
  });

  final List<OwnedCollectible> items;
  final List<CurvedAnimation> appearAnimations;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final count = collectionGridCrossAxisCount(width);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.58,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final owned = items[index];
            final anim = index < appearAnimations.length ? appearAnimations[index] : null;
            return CollectionShelfCard(
              key: ValueKey(owned.collectible.id),
              owned: owned,
              appear: anim,
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}
