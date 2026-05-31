import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:flutter/foundation.dart';

/// Shell branch index for the Collection tab in [StatefulShellRoute.indexedStack].
const int kCollectionShellBranchIndex = 0;

/// Shell branch index for the Home (Discover) tab.
const int kHomeShellBranchIndex = 1;

/// Shell branch index for the Market tab.
const int kMarketShellBranchIndex = 2;

/// Fired when the user re-taps the active bottom-nav tab (scroll-to-top hook).
final class ShellTabReselectBus {
  ShellTabReselectBus._();

  static final ShellTabReselectBus instance = ShellTabReselectBus._();

  final ValueNotifier<int?> reselectedBranch = ValueNotifier<int?>(null);

  /// Set when Market is re-tapped; consumed when [MarketScreen] or a sub-route
  /// handles [resetMarketBrowseToRoot]. Covers search → listing → reselect where
  /// [goBranch] disposes listeners before [MarketScreen] mounts.
  bool _marketBrowseRootResetPending = false;

  void notify(int branchIndex) {
    if (branchIndex == kMarketShellBranchIndex) {
      _marketBrowseRootResetPending = true;
      MarketSearchTrace.event(
        'shell ShellTabReselectBus.notify(market) after goBranch',
      );
    }
    reselectedBranch.value = branchIndex;
  }

  bool get isMarketBrowseRootResetPending => _marketBrowseRootResetPending;

  /// Returns whether a Market browse-root reset was requested and clears the flag.
  bool takeMarketBrowseRootResetPending() {
    final pending = _marketBrowseRootResetPending;
    _marketBrowseRootResetPending = false;
    return pending;
  }

  /// Drops a stale reselect request when the Market branch is left without handling.
  void clearMarketBrowseRootResetPending() {
    _marketBrowseRootResetPending = false;
  }
}
