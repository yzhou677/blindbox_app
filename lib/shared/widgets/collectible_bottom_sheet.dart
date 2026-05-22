import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// Builds sheet body content wired to the modal [ScrollController].
typedef CollectibleSheetWidgetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Exposes the sheet scroll controller to descendants.
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
    clipBehavior: Clip.antiAlias,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          child: _CollectibleSheetScrollHost(builder: builder),
        ),
      );
    },
  );
}

/// Owns scroll controller; sheet height comes from [FractionallySizedBox], not
/// [DraggableScrollableSheet], so the modal surface does not paint empty space
/// above the drag handle.
class _CollectibleSheetScrollHost extends StatefulWidget {
  const _CollectibleSheetScrollHost({required this.builder});

  final CollectibleSheetWidgetBuilder builder;

  @override
  State<_CollectibleSheetScrollHost> createState() =>
      _CollectibleSheetScrollHostState();
}

class _CollectibleSheetScrollHostState extends State<_CollectibleSheetScrollHost> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CollectibleSheetScope(
      scrollController: _scrollController,
      child: CollectibleSheetFocusFrame(
        child: widget.builder(context, _scrollController),
      ),
    );
  }
}
