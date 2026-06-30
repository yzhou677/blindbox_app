import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps [catalogBundleRevisionProvider] alive so bundle replacement listeners
/// register for the app lifetime and dependent providers rebuild naturally.
class CatalogBundleRefreshBridge extends ConsumerWidget {
  const CatalogBundleRefreshBridge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(catalogBundleRevisionProvider);
    return child;
  }
}
