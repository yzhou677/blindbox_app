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

  void notify(int branchIndex) {
    reselectedBranch.value = branchIndex;
  }
}
