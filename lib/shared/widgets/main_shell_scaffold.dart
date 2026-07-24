import 'dart:async';

import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/market/application/market_browse_root_navigation.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart'
    show CollectionModalOverlayRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Anchored main navigation — full-width dock (no ambiguous “floating” hit target).
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Unselected = outline fill; selected = solid fill — same Rounded family.
  static final List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: const Icon(Symbols.collections_bookmark_rounded, fill: 0),
      selectedIcon: const Icon(Symbols.collections_bookmark_rounded, fill: 1),
      label: 'Collection',
    ),
    NavigationDestination(
      icon: const Icon(Symbols.explore_rounded, fill: 0),
      selectedIcon: const Icon(Symbols.explore_rounded, fill: 1),
      label: 'Discover',
    ),
    NavigationDestination(
      icon: const Icon(Symbols.storefront_rounded, fill: 0),
      selectedIcon: const Icon(Symbols.storefront_rounded, fill: 1),
      label: 'Market',
    ),
  ];

  void _onDestinationSelected(WidgetRef ref, BuildContext context, int index) {
    if (shell.currentIndex == index) {
      if (index == kCollectionShellBranchIndex) {
        unawaited(CollectionModalOverlayRegistry.instance.dismissAll());
      }
      if (index == kMarketShellBranchIndex) {
        prepareMarketShellTabReselectToBrowseRoot(
          ref,
          routePath: GoRouter.of(context).state.uri.path,
        );
      }
      shell.goBranch(index, initialLocation: true);
      ShellTabReselectBus.instance.notify(index);
      return;
    }
    if (shell.currentIndex == kCollectionShellBranchIndex &&
        index != kCollectionShellBranchIndex) {
      unawaited(CollectionModalOverlayRegistry.instance.dismissAll());
    }
    shell.goBranch(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Material(
        color: Color.lerp(
          scheme.surfaceContainerLow,
          scheme.primaryContainer,
          isLight ? 0.14 : 0.11,
        ),
        elevation: isLight ? 5 : 7,
        shadowColor: Color.lerp(
          scheme.shadow,
          scheme.primary,
          isLight ? 0.06 : 0.12,
        )!.withValues(alpha: isLight ? 0.11 : 0.22),
        surfaceTintColor: scheme.primary.withValues(
          alpha: isLight ? 0.07 : 0.09,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: Color.lerp(
                scheme.outlineVariant,
                scheme.primary,
                isLight ? 0.16 : 0.16,
              )!.withValues(alpha: isLight ? 0.5 : 0.38),
            ),
            NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(ref, context, index),
              height: 64,
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _destinations,
            ),
          ],
        ),
      ),
    );
  }
}
