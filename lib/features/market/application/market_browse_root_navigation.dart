import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Market tab root — feed chrome (filters, Chasers, Collectibles header).
const String kMarketBrowseRootPath = '/market';

/// Full-screen search overlay route under the Market branch.
const String kMarketSearchRoutePath = '/market/search';

bool isMarketSearchRoutePath(String path) =>
    path == kMarketSearchRoutePath ||
    path.startsWith('$kMarketSearchRoutePath/');

/// True when [path] is the Market feed root (not search, listing detail, etc.).
bool isMarketBrowseRootPath(String path) => path == kMarketBrowseRootPath;

/// Debug log for overlay / committed / immersive while fixing browse-root chrome.
void logMarketBrowseChromeState(
  WidgetRef ref, {
  required String phase,
  required String routePath,
}) {
  if (!kDebugMode) return;
  final overlayOpen = ref.read(marketSearchOverlayOpenProvider);
  final search = ref.read(marketSearchBrowseNotifierProvider);
  final immersive = overlayOpen && search.isCommitted;
  MarketSearchTrace.event(
    'browseChrome[$phase] route=$routePath '
    'overlay=$overlayOpen committed=${search.isCommitted} immersive=$immersive',
  );
}

/// Clears committed search + overlay flag so [MarketScreen] is not in immersive mode.
void clearMarketSearchOverlaySession(WidgetRef ref) {
  ref.read(marketSearchBrowseNotifierProvider.notifier).clearSession();
  ref.read(marketSearchOverlayOpenProvider.notifier).setOpen(false);
}

/// Clears overlay session **before** [StatefulNavigationShell.goBranch] drops search/listing.
///
/// [MarketScreen] stays on `/market` while children stack; without this, the first root
/// frame can paint with `overlayOpen && isCommitted` (immersive, no Chasers/chips).
void prepareMarketShellTabReselectToBrowseRoot(
  WidgetRef ref, {
  required String routePath,
}) {
  logMarketBrowseChromeState(ref, phase: 'shell_before_clear', routePath: routePath);
  clearMarketSearchOverlaySession(ref);
  logMarketBrowseChromeState(ref, phase: 'shell_after_clear', routePath: routePath);
}

/// Navigates the Market branch stack back to [kMarketBrowseRootPath].
void goToMarketBrowseRoot(BuildContext context) {
  final path = GoRouterState.of(context).uri.path;
  if (isMarketBrowseRootPath(path)) return;
  GoRouter.of(context).go(kMarketBrowseRootPath);
}

/// Pops collectible preview sheets on the Market branch navigator only.
void dismissMarketBranchModalOverlays(BuildContext context) {
  final navigator = Navigator.maybeOf(context);
  if (navigator == null || !navigator.canPop() || navigator.userGestureInProgress) {
    return;
  }
  navigator.popUntil((route) => route is PageRoute);
}

/// Tab reselect on a Market sub-route: dismiss sheets, clear search, go `/market`.
void resetMarketBrowseToRoot({
  required WidgetRef ref,
  required BuildContext context,
}) {
  final routePath = GoRouter.of(context).state.uri.path;
  logMarketBrowseChromeState(ref, phase: 'reset_before_clear', routePath: routePath);
  dismissMarketBranchModalOverlays(context);
  clearMarketSearchOverlaySession(ref);
  logMarketBrowseChromeState(ref, phase: 'reset_after_clear', routePath: routePath);
  // Always go — parent [MarketScreen] can report `/market` while listing/search
  // child routes are still on the branch stack.
  GoRouter.of(context).go(kMarketBrowseRootPath);
  logMarketBrowseChromeState(
    ref,
    phase: 'reset_after_go',
    routePath: kMarketBrowseRootPath,
  );
}

/// Marks a Market tab reselect as handled (search session cleared + routed).
void completeMarketBrowseRootReselect({
  required WidgetRef ref,
  required BuildContext context,
}) {
  resetMarketBrowseToRoot(ref: ref, context: context);
  ShellTabReselectBus.instance.takeMarketBrowseRootResetPending();
}

/// [ShellTabReselectBus] hook for Market sub-routes (listing, search).
///
/// Runs synchronously on notify — after [goBranch] is requested but before the
/// sub-route is disposed, so [go('/market')] and sheet dismiss still apply.
void handleMarketShellTabReselected({
  required WidgetRef ref,
  required BuildContext context,
}) {
  if (ShellTabReselectBus.instance.reselectedBranch.value !=
      kMarketShellBranchIndex) {
    return;
  }
  if (!context.mounted) return;
  completeMarketBrowseRootReselect(ref: ref, context: context);
}
