import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps [catalogBundleRevisionProvider] alive and owns catalog meta lifecycle:
/// snapshot listener while foreground, refresh on resume, cancel in background.
class CatalogBundleRefreshBridge extends ConsumerStatefulWidget {
  const CatalogBundleRefreshBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CatalogBundleRefreshBridge> createState() =>
      _CatalogBundleRefreshBridgeState();
}

class _CatalogBundleRefreshBridgeState
    extends ConsumerState<CatalogBundleRefreshBridge>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer so the first frame is not blocked on Firebase listener attach.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CatalogBundleCache.startMetaListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CatalogBundleCache.stopMetaListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        CatalogBundleCache.startMetaListener();
        CatalogBundleCache.refreshFromFirestore();
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        CatalogBundleCache.stopMetaListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(catalogBundleRevisionProvider);
    return widget.child;
  }
}
