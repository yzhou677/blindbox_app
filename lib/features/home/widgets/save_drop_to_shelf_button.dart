import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight “put this drop on my shelf” — icon state only (no snackbars).
class SaveDropToShelfButton extends ConsumerWidget {
  const SaveDropToShelfButton({super.key, required this.collectible});

  final Collectible collectible;

  String get _catalogKey => 'drop-${collectible.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final onShelf = ref.watch(
      collectionNotifierProvider.select((s) => s.hasTemplateOnShelf(_catalogKey)),
    );

    return IconButton(
      tooltip: onShelf ? 'On shelf' : 'Add to shelf',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onShelf
          ? null
          : () => ref.read(collectionNotifierProvider.notifier).addSeriesFromDrop(collectible),
      icon: Icon(
        onShelf ? Icons.bookmark_added_rounded : Icons.add_circle_outline_rounded,
        size: 22,
        color: onShelf
            ? scheme.primary.withValues(alpha: 0.45)
            : scheme.primary.withValues(alpha: 0.92),
      ),
    );
  }
}
