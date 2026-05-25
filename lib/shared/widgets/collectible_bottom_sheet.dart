import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// Builds sheet body content wired to the sheet [ScrollController].
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

/// Scroll physics for sheet lists.
ScrollPhysics collectibleSheetScrollPhysics([ScrollPhysics? parent]) {
  return const ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );
}

/// Sheet scroll body. Optional [header] (handle + title) sits above the list.
class CollectibleSheetScrollView extends StatelessWidget {
  const CollectibleSheetScrollView({
    super.key,
    required this.slivers,
    this.header,
    this.controller,
  });

  final List<Widget> slivers;

  /// Drag handle + title — fixed height, not scrolled.
  final Widget? header;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final scroll = controller ?? CollectibleSheetScope.scrollControllerOf(context);
    assert(
      scroll != null,
      'CollectibleSheetScrollView requires a scroll controller '
      '(pass it explicitly or build under CollectibleSheetScope).',
    );

    final scrollView = CustomScrollView(
      controller: scroll,
      physics: collectibleSheetScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: slivers,
    );

    if (header == null) {
      return scrollView;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header!,
        Expanded(child: scrollView),
      ],
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

/// Screen-height fractions (used by tests and height helpers).
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

/// Presents a collectible bottom sheet as one physical surface.
///
/// One route [Material] + native [enableDrag]; fixed height via [_CollectibleSheetHost].
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

  final surface = backgroundColor ?? scheme.surface;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetElevation = isDark ? 10.0 : 12.0;

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
    backgroundColor: surface,
    elevation: sheetElevation,
    shape: AppRadii.sheetShape,
    clipBehavior: Clip.antiAlias,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      final sheetHeight = MediaQuery.sizeOf(ctx).height * openFraction;

      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: _CollectibleSheetHost(
          height: sheetHeight,
          child: builder,
        ),
      );
    },
  );
}

/// Owns a [ScrollController] for the sheet body for the lifetime of the modal.
class _CollectibleSheetHost extends StatefulWidget {
  const _CollectibleSheetHost({
    required this.height,
    required this.child,
  });

  final double height;
  final CollectibleSheetWidgetBuilder child;

  @override
  State<_CollectibleSheetHost> createState() => _CollectibleSheetHostState();
}

class _CollectibleSheetHostState extends State<_CollectibleSheetHost> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CollectibleSheetScope(
        scrollController: _scrollController,
        child: widget.child(context, _scrollController),
      ),
    );
  }
}
