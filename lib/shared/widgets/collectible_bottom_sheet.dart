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

/// Child-size ratios for [DraggableScrollableSheet] inside a height-capped host.
final class CollectibleSheetDragSizes {
  const CollectibleSheetDragSizes({
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
}

CollectibleSheetDragSizes resolveCollectibleSheetDragSizes({
  required double heightFactor,
  double minScreenFraction = FeedRhythm.sheetMinScreenFraction,
}) {
  final open = heightFactor.clamp(0.2, 0.98);
  final min = minScreenFraction.clamp(0.18, open);

  double ratio(double screenFraction) =>
      (screenFraction / open).clamp(0.15, 1.0);

  return CollectibleSheetDragSizes(
    initialChildSize: 1.0,
    minChildSize: ratio(min),
    maxChildSize: 1.0,
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

/// Presents a collectible bottom sheet with forgiving drag / tap / back dismiss.
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
  final heightFactor = resolveCollectibleSheetHeightFactor(
    openScreenFraction: heightFraction,
    minScreenFraction:
        minHeightFraction ?? FeedRhythm.sheetMinScreenFraction,
    maxScreenFraction: maxHeightFraction ?? heightFraction,
  );
  final dragSizes = resolveCollectibleSheetDragSizes(
    heightFactor: heightFactor,
    minScreenFraction:
        minHeightFraction ?? FeedRhythm.sheetMinScreenFraction,
  );

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: true,
    enableDrag: false,
    showDragHandle: false,
    barrierColor: CollectibleImmersion.sheetBarrier(scheme),
    sheetAnimationStyle: CollectibleMotion.sheetAnimationStyle(),
    backgroundColor: backgroundColor ?? scheme.surface,
    shape: AppRadii.sheetShape,
    clipBehavior: Clip.antiAlias,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          child: _CollectibleDraggableSheetHost(
            initialChildSize: dragSizes.initialChildSize,
            minChildSize: dragSizes.minChildSize,
            maxChildSize: dragSizes.maxChildSize,
            builder: builder,
          ),
        ),
      );
    },
  );
}

/// [FractionallySizedBox] caps modal height; [DraggableScrollableSheet] links
/// scroll and drag so downward pulls at scroll top dismiss the sheet.
class _CollectibleDraggableSheetHost extends StatelessWidget {
  const _CollectibleDraggableSheetHost({
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.builder,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final CollectibleSheetWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: true,
      snapSizes: <double>{minChildSize, initialChildSize, maxChildSize}.toList()
        ..sort(),
      snapAnimationDuration: CollectibleMotion.sheetDismiss,
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return CollectibleSheetScope(
          scrollController: scrollController,
          child: CollectibleSheetFocusFrame(
            child: builder(context, scrollController),
          ),
        );
      },
    );
  }
}
