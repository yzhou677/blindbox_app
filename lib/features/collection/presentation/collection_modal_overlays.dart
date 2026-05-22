import 'package:blindbox_app/core/theme/app_radii.dart';
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

/// Collection-owned modal bottom sheet — scoped to the Collection branch navigator.
Future<T?> showCollectionModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool showDragHandle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: shape ?? AppRadii.sheetShape,
    showDragHandle: showDragHandle,
    builder: builder,
  );
}
