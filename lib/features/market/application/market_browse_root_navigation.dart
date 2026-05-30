import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:flutter/widgets.dart';
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

/// Clears committed search + overlay flag so [MarketScreen] is not in immersive mode.
void clearMarketSearchOverlaySession(WidgetRef ref) {
  ref.read(marketSearchBrowseNotifierProvider.notifier).clearSession();
  ref.read(marketSearchOverlayOpenProvider.notifier).setOpen(false);
}

/// Navigates the Market branch stack back to [kMarketBrowseRootPath].
void goToMarketBrowseRoot(BuildContext context) {
  final path = GoRouterState.of(context).uri.path;
  if (isMarketBrowseRootPath(path)) return;
  GoRouter.of(context).go(kMarketBrowseRootPath);
}

/// Tab reselect / shell reset: restore feed session and pop off `/market/search`.
void resetMarketBrowseToRoot({
  required WidgetRef ref,
  required BuildContext context,
}) {
  clearMarketSearchOverlaySession(ref);
  goToMarketBrowseRoot(context);
}
