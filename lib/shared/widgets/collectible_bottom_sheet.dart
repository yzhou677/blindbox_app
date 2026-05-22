import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:flutter/material.dart';

/// Presents a collectible-style bottom sheet (shared shape, height, insets).
Future<T?> showCollectibleBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  double heightFraction = FeedRhythm.sheetHeightFraction,
  Color? backgroundColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: backgroundColor ?? scheme.surface,
    shape: AppRadii.sheetShape,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      final h = MediaQuery.sizeOf(ctx).height * heightFraction;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(height: h, child: builder(ctx)),
      );
    },
  );
}
