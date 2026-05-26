import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';

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

  Future<void> Function()? _dismissBranchOverlays;

  // Reentrancy guard over the full async pop lifecycle.  While this future is
  // non-null, repeated dismiss requests are folded into the same in-flight
  // operation and cannot trigger duplicate pop completion.
  Future<void>? _inFlightDismiss;

  void register(Future<void> Function() dismiss) {
    _dismissBranchOverlays = dismiss;
  }

  void unregister() {
    _dismissBranchOverlays = null;
  }

  /// Idempotent dismiss across the full async pop animation lifecycle. Safe to
  /// call from multiple navigation triggers (tab switch, router listener, etc).
  Future<void> dismissAll() {
    if (_inFlightDismiss != null) return _inFlightDismiss!;
    final cb = _dismissBranchOverlays;
    if (cb == null) return Future<void>.value();
    final op = cb();
    _inFlightDismiss = op.whenComplete(() {
      _inFlightDismiss = null;
    });
    return _inFlightDismiss!;
  }

  /// Forces an immediate clear of the in-flight guard — intended for tests only.
  @visibleForTesting
  void resetGuardForTest() {
    _inFlightDismiss = null;
  }
}

/// Pops modal routes on the Collection branch navigator (bottom sheets, etc.).
///
/// Prefer [CollectionModalOverlayRegistry.dismissAll] — this helper is the
/// low-level pop implementation invoked by the registered callback.  It
/// already short-circuits when there is nothing to pop or when a user swipe
/// gesture is in progress on the navigator.
Future<void> dismissCollectionModalOverlays(BuildContext context) async {
  final navigator = Navigator.of(context);
  // Nothing to dismiss.
  if (!navigator.canPop()) return;
  // Avoid racing a user swipe-to-pop gesture already in flight.  iOS-style
  // gestures and some custom transitions can leave the navigator with
  // `userGestureInProgress == true` during which `popUntil` can complete a
  // route's pop-future twice.
  if (navigator.userGestureInProgress) return;

  // Pop one route at a time and await each completion before attempting the
  // next. This prevents double-completing a route's pop future during rapid
  // repeated dismiss requests.
  while (navigator.canPop()) {
    if (navigator.userGestureInProgress) return;
    final didPop = await navigator.maybePop();
    if (!didPop) return;
  }
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
