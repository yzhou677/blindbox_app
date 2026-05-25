import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// Builds sheet body content wired to the modal [ScrollController].
typedef CollectibleSheetWidgetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Exposes the [DraggableScrollableSheet] scroll controller to descendants.
class CollectibleSheetScope extends InheritedWidget {
  const CollectibleSheetScope({
    super.key,
    required this.scrollController,
    required super.child,
  });

  final ScrollController scrollController;

  static CollectibleSheetScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CollectibleSheetScope>();
  }

  static ScrollController? scrollControllerOf(BuildContext context) {
    return maybeOf(context)?.scrollController;
  }

  @override
  bool updateShouldNotify(CollectibleSheetScope oldWidget) {
    return scrollController != oldWidget.scrollController;
  }
}

/// Scroll physics for sheet lists — cooperates with [DraggableScrollableSheet].
///
/// [AlwaysScrollableScrollPhysics] keeps short sheets draggable at scroll top;
/// [ClampingScrollPhysics] hands off downward pulls to sheet dismissal.
ScrollPhysics collectibleSheetScrollPhysics([ScrollPhysics? parent]) {
  return const ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// One [CustomScrollView] for the sheet — header, list, and footer share the
/// linked controller so drag-from-handle and scroll-to-dismiss stay continuous.
class CollectibleSheetScrollView extends StatelessWidget {
  const CollectibleSheetScrollView({
    super.key,
    required this.slivers,
    this.controller,
  });

  final List<Widget> slivers;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final scroll = controller ?? CollectibleSheetScope.scrollControllerOf(context);
    return CustomScrollView(
      controller: scroll,
      physics: collectibleSheetScrollPhysics(),
      slivers: slivers,
    );
  }
}

/// Target visible height as a fraction of the full screen.
double resolveCollectibleSheetHeightFactor({
  double openScreenFraction = FeedRhythm.sheetOpenScreenFraction,
  double minScreenFraction = FeedRhythm.sheetMinScreenFraction,
  double maxScreenFraction = FeedRhythm.sheetMaxChildSize,
}) {
  final max = maxScreenFraction.clamp(0.5, 0.98);
  final open = openScreenFraction.clamp(minScreenFraction, max);
  return open;
}

/// Screen-height fractions for [DraggableScrollableSheet] (parent = full screen).
final class CollectibleSheetExtents {
  const CollectibleSheetExtents({
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
}

CollectibleSheetExtents resolveCollectibleSheetExtents({
  required double openScreenFraction,
  double minScreenFraction = FeedRhythm.sheetMinScreenFraction,
  double maxScreenFraction = FeedRhythm.sheetMaxChildSize,
}) {
  final open = openScreenFraction.clamp(0.2, 0.98);
  final min = minScreenFraction.clamp(0.12, open);
  final max = maxScreenFraction.clamp(open, 0.98);
  return CollectibleSheetExtents(
    initialChildSize: open,
    minChildSize: min,
    maxChildSize: max,
  );
}

/// Horizontal + bottom safe inset for sheet bodies.
///
/// Top spacing lives only on [CollectibleSheetChrome] (drag handle + title).
class CollectibleSheetInsets extends StatelessWidget {
  const CollectibleSheetInsets({
    super.key,
    required this.child,
    this.extraBottom = FeedRhythm.sheetBodyBottomInset,
  });

  final Widget child;
  final double extraBottom;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FeedRhythm.sheetHorizontal,
        0,
        FeedRhythm.sheetHorizontal,
        bottom + extraBottom,
      ),
      child: child,
    );
  }
}

/// Presents a collectible bottom sheet — single surface, native drag dismiss.
///
/// [showModalBottomSheet] [enableDrag] moves the whole route; [DraggableScrollableSheet]
/// links list scroll to resize. One [Material] shell (no nested chrome layers).
Future<T?> showCollectibleBottomSheet<T>({
  required BuildContext context,
  required CollectibleSheetWidgetBuilder builder,
  bool useRootNavigator = false,
  double heightFraction = FeedRhythm.sheetOpenScreenFraction,
  double? minHeightFraction,
  double? maxHeightFraction,
  Color? backgroundColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  final openFraction = resolveCollectibleSheetHeightFactor(
    openScreenFraction: heightFraction,
    minScreenFraction:
        minHeightFraction ?? FeedRhythm.sheetMinScreenFraction,
    maxScreenFraction: maxHeightFraction ?? heightFraction,
  );
  final extents = resolveCollectibleSheetExtents(
    openScreenFraction: openFraction,
    minScreenFraction:
        minHeightFraction ?? FeedRhythm.sheetMinScreenFraction,
    maxScreenFraction:
        maxHeightFraction ?? openFraction,
  );

  final surface = backgroundColor ?? scheme.surface;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    barrierColor: CollectibleImmersion.sheetBarrier(scheme),
    sheetAnimationStyle: CollectibleMotion.sheetAnimationStyle(),
    backgroundColor: Colors.transparent,
    elevation: 0,
    clipBehavior: Clip.none,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: extents.initialChildSize,
          minChildSize: extents.minChildSize,
          maxChildSize: extents.maxChildSize,
          snap: false,
          shouldCloseOnMinExtent: true,
          builder: (context, scrollController) {
            return _CollectibleSheetShell(
              color: surface,
              isDark: isDark,
              child: CollectibleSheetScope(
                scrollController: scrollController,
                child: builder(context, scrollController),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Rounded elevated shell — the only [Material] in the sheet stack.
class _CollectibleSheetShell extends StatelessWidget {
  const _CollectibleSheetShell({
    required this.color,
    required this.isDark,
    required this.child,
  });

  final Color color;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: isDark ? 10 : 12,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
      clipBehavior: Clip.antiAlias,
      shape: AppRadii.sheetShape,
      child: child,
    );
  }
}
