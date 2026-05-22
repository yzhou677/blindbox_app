import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Index of the `/collection` branch in [StatefulShellRoute.indexedStack] (see [appRouter]).
const int kCollectionShellBranchIndex = 2;

/// Dismisses Collection-branch modal routes when the user leaves the Collection tab.
final class CollectionModalOverlayRegistry {
  CollectionModalOverlayRegistry._();

  static final CollectionModalOverlayRegistry instance =
      CollectionModalOverlayRegistry._();

  VoidCallback? _dismissBranchOverlays;

  void register(VoidCallback dismiss) {
    _dismissBranchOverlays = dismiss;
  }

  void unregister() {
    _dismissBranchOverlays = null;
  }

  void dismissAll() {
    _dismissBranchOverlays?.call();
  }
}

/// Pops modal routes on the Collection branch navigator (bottom sheets, etc.).
void dismissCollectionModalOverlays(BuildContext context) {
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return;
  navigator.popUntil((route) => route.isFirst);
}

/// Collection-branch sheets — same drag/dismiss behavior as [showCollectibleBottomSheet].
Future<T?> showCollectionModalBottomSheet<T>({
  required BuildContext context,
  required CollectibleSheetWidgetBuilder builder,
  double heightFraction = FeedRhythm.sheetAddSeriesOpenScreenFraction,
  Color? backgroundColor,
}) {
  return showCollectibleBottomSheet<T>(
    context: context,
    useRootNavigator: false,
    heightFraction: heightFraction,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}
