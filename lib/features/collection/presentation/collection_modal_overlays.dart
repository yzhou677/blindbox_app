import 'dart:async';

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
    final op = _runDismissAfterFrame(cb);
    _inFlightDismiss = op
        .then((_) => _holdDismissFrames())
        .whenComplete(() {
      _inFlightDismiss = null;
    });
    return _inFlightDismiss!;
  }

  Future<void> _runDismissAfterFrame(Future<void> Function() dismiss) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      return dismiss();
    }
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        await dismiss();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    SchedulerBinding.instance.scheduleFrame();
    return completer.future;
  }

  Future<void> _holdDismissFrames() async {
    // Keep dismiss requests coalesced for a short transition window without
    // using wall-clock timers (timer-based cooldowns create pending-timer
    // invariants in widget tests). Two frames is enough to cover rapid
    // same-gesture duplicate triggers.
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
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
  if (!navigator.canPop() || navigator.userGestureInProgress) return;

  // Critical: only dismiss modal overlays (PopupRoute), never page routes.
  //
  // Using `route.isFirst` can pop page routes like `/collection/insights`.
  // If another navigation action (e.g. `context.go('/collection')`) runs in
  // parallel, the same page route may be completed twice -> `Future already
  // completed`.
  //
  // Stop as soon as we reach a PageRoute (Collection/Insights page layer).
  navigator.popUntil((route) => route is PageRoute);
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
