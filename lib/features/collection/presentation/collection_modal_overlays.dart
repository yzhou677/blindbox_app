import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Index of the `/collection` branch in [StatefulShellRoute.indexedStack] (see [appRouter]).
const int kCollectionShellBranchIndex = 2;

/// Dismisses Collection-branch modal routes when the user leaves the Collection tab.
///
/// All external dismiss requests **must** go through [dismissAll] — never call
/// the registered callback or [dismissCollectionModalOverlays] directly from
/// outside this file.  Funneling every path through [dismissAll] ensures that
/// the reentrancy guard catches multi-trigger races (e.g. tab-switch firing
/// both the shell scaffold's direct dismiss and the GoRouter location
/// listener's dismiss simultaneously).
final class CollectionModalOverlayRegistry {
  CollectionModalOverlayRegistry._();

  static final CollectionModalOverlayRegistry instance =
      CollectionModalOverlayRegistry._();

  VoidCallback? _dismissBranchOverlays;

  // Reentrancy guard.  `Navigator.popUntil` is synchronous in stack mutation
  // but the exit animation completes on the next frame.  Without this guard,
  // a second dismiss arriving during the animation can call `pop()` on a
  // route that's already mid-pop, triggering `Future already completed` when
  // the route's `_popCompleter` resolves twice.
  bool _dismissing = false;

  void register(VoidCallback dismiss) {
    _dismissBranchOverlays = dismiss;
  }

  void unregister() {
    _dismissBranchOverlays = null;
  }

  /// Idempotent dismiss — subsequent calls within the same frame are no-ops
  /// while the previous dismiss animation completes.  Safe to call from
  /// multiple navigation triggers (tab switch, router listener, etc.).
  void dismissAll() {
    if (_dismissing) return;
    final cb = _dismissBranchOverlays;
    if (cb == null) return;
    _dismissing = true;
    try {
      cb();
    } finally {
      // Clear the flag after the current frame settles so the next legitimate
      // dismiss (e.g. user opens a sheet then switches tabs again) is allowed.
      // Using SchedulerBinding (not WidgetsBinding) so tests without a
      // widgets binding still receive the post-frame reset.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _dismissing = false;
      });
    }
  }

  /// Forces an immediate clear of the guard — intended for tests only.
  @visibleForTesting
  void resetGuardForTest() {
    _dismissing = false;
  }
}

/// Pops modal routes on the Collection branch navigator (bottom sheets, etc.).
///
/// Prefer [CollectionModalOverlayRegistry.dismissAll] — this helper is the
/// low-level pop implementation invoked by the registered callback.  It
/// already short-circuits when there is nothing to pop or when a user swipe
/// gesture is in progress on the navigator.
void dismissCollectionModalOverlays(BuildContext context) {
  final navigator = Navigator.of(context);
  // Nothing to dismiss.
  if (!navigator.canPop()) return;
  // Avoid racing a user swipe-to-pop gesture already in flight.  iOS-style
  // gestures and some custom transitions can leave the navigator with
  // `userGestureInProgress == true` during which `popUntil` can complete a
  // route's pop-future twice.
  if (navigator.userGestureInProgress) return;
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
