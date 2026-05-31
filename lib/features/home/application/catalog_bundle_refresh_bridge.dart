import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invalidates [homeFeedSnapshotProvider] when [CatalogBundleCache.refreshFromFirestore]
/// replaces the in-memory catalog (Discover Latest/Trending stay in sync).
class CatalogBundleRefreshBridge extends ConsumerStatefulWidget {
  const CatalogBundleRefreshBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CatalogBundleRefreshBridge> createState() =>
      _CatalogBundleRefreshBridgeState();
}

class _CatalogBundleRefreshBridgeState
    extends ConsumerState<CatalogBundleRefreshBridge> {
  @override
  void initState() {
    super.initState();
    CatalogBundleCache.onBundleReplaced = _onCatalogBundleReplaced;
  }

  @override
  void dispose() {
    if (CatalogBundleCache.onBundleReplaced == _onCatalogBundleReplaced) {
      CatalogBundleCache.onBundleReplaced = null;
    }
    super.dispose();
  }

  void _onCatalogBundleReplaced() {
    if (!mounted) return;
    ref.invalidate(homeFeedSnapshotProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
