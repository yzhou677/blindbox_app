import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
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

/// Presents a collectible bottom sheet with forgiving drag / tap / back dismiss.
Future<T?> showCollectibleBottomSheet<T>({
  required BuildContext context,
  required CollectibleSheetWidgetBuilder builder,
  bool useRootNavigator = false,
  double heightFraction = FeedRhythm.sheetHeightFraction,
  double? minHeightFraction,
  double? maxHeightFraction,
  Color? backgroundColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  final initial = heightFraction.clamp(
    FeedRhythm.sheetMinChildSize,
    FeedRhythm.sheetMaxChildSize,
  );
  final min = (minHeightFraction ?? FeedRhythm.sheetMinChildSize).clamp(0.2, initial);
  final max = (maxHeightFraction ?? FeedRhythm.sheetMaxChildSize).clamp(
    initial,
    0.98,
  );

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    backgroundColor: backgroundColor ?? scheme.surface,
    shape: AppRadii.sheetShape,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      final height = MediaQuery.sizeOf(ctx).height;

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SizedBox(
          height: height,
          child: _CollectibleDraggableSheetHost(
            initialChildSize: initial,
            minChildSize: min,
            maxChildSize: max,
            builder: builder,
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
          child: builder(context, scrollController),
        );
      },
    );
  }
}
