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

/// Scroll physics for sheet lists — always scrollable so overscroll dismiss works.
ScrollPhysics collectibleSheetScrollPhysics([ScrollPhysics? parent]) {
  return const AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );
}

/// Maps screen-height targets to [DraggableScrollableSheet] child sizes.
///
/// The modal host matches the open height so `initialChildSize: 1` fills the
/// panel at rest — no empty surface above the drag handle. Pass a larger
/// [maxScreenFraction] only when a sheet must drag taller than its open height.
final class CollectibleSheetExtent {
  const CollectibleSheetExtent({
    required this.hostHeight,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
  });

  final double hostHeight;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
}

CollectibleSheetExtent resolveCollectibleSheetExtent({
  required double screenHeight,
  double openScreenFraction = FeedRhythm.sheetOpenScreenFraction,
  double minScreenFraction = FeedRhythm.sheetMinScreenFraction,
  double maxScreenFraction = FeedRhythm.sheetMaxChildSize,
}) {
  final max = maxScreenFraction.clamp(0.5, 0.98);
  final open = openScreenFraction.clamp(minScreenFraction, max);
  final min = minScreenFraction.clamp(0.18, open);
  final hostFraction = open;
  final hostHeight = screenHeight * hostFraction;

  double childSize(double screenFraction) =>
      (screenFraction / hostFraction).clamp(0.15, 1.0);

  return CollectibleSheetExtent(
    hostHeight: hostHeight,
    initialChildSize: 1.0,
    minChildSize: childSize(min),
    maxChildSize: childSize(max),
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
    backgroundColor: backgroundColor ?? scheme.surface,
    shape: AppRadii.sheetShape,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      final screenHeight = MediaQuery.sizeOf(ctx).height;
      final extent = resolveCollectibleSheetExtent(
        screenHeight: screenHeight,
        openScreenFraction: heightFraction,
        minScreenFraction:
            minHeightFraction ?? FeedRhythm.sheetMinScreenFraction,
        maxScreenFraction: maxHeightFraction ?? heightFraction,
      );

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: extent.hostHeight,
            child: _CollectibleDraggableSheetHost(
              initialChildSize: extent.initialChildSize,
              minChildSize: extent.minChildSize,
              maxChildSize: extent.maxChildSize,
              builder: builder,
            ),
          ),
        ),
      );
    },
  );
}

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
      snapSizes: <double>{
        minChildSize,
        initialChildSize,
        maxChildSize,
      }.toList()
        ..sort(),
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
