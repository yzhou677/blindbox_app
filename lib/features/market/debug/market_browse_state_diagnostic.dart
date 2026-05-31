import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:blindbox_app/features/market/widgets/market_browse_session_transition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canonical one-line browse snapshot for live-gateway hybrid debugging.
///
/// Filter logcat: `MarketSearch` + `browseSnapshot`.
abstract final class MarketBrowseStateDiagnostic {
  static void log(WidgetRef ref, {required String phase, String? routePath}) {
    if (!kDebugMode) return;
    _emit(phase: phase, routePath: routePath, read: ref.read);
  }

  static void logNotifier(Ref ref, {required String phase, String? routePath}) {
    if (!kDebugMode) return;
    _emit(phase: phase, routePath: routePath, read: ref.read);
  }

  /// Same snapshot via [ProviderContainer] (integration / audit tests).
  static void logContainer(
    ProviderContainer container, {
    required String phase,
    String? routePath,
  }) {
    if (!kDebugMode) return;
    _emit(
      phase: phase,
      routePath: routePath,
      read: container.read,
    );
  }

  static void _emit({
    required String phase,
    String? routePath,
    required T Function<T>(ProviderListenable<T> provider) read,
  }) {
    final search = read(marketSearchBrowseNotifierProvider);
    final overlayOpen = read(marketSearchOverlayOpenProvider);
    final activeQuery = read(activeMarketBrowseQueryProvider);
    final immersive = overlayOpen && search.isCommitted;

    final gatewayActive = MarketGatewayConfig.isActive;
    final live = gatewayActive
        ? read(marketLiveBrowseControllerProvider)
        : null;
    final liveSig = gatewayActive && live != null ? live.querySignature : 'n/a';
    final sessionRows = CollectibleMarketSession.instance.isInstalled
        ? CollectibleMarketSession.instance.list.length
        : 0;
    final visibleRows = read(visibleCollectibleMarketSnapshotsProvider).length;
    final sessionTransitioning = gatewayActive && live != null
        ? marketBrowseSessionTransitionActive(activeQuery, live)
        : false;

    MarketSearchTrace.event(
      'browseSnapshot[$phase] '
      'activeSig=${activeQuery.signature} '
      'liveSig=$liveSig '
      'sessionRows=$sessionRows '
      'visibleRows=$visibleRows '
      'sessionTransitioning=$sessionTransitioning '
      'overlay=$overlayOpen '
      'committed=${search.isCommitted} '
      'immersive=$immersive '
      'route=${routePath ?? "?"} '
      'gateway=$gatewayActive',
    );
  }
}
