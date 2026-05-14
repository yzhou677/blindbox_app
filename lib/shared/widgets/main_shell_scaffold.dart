import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Anchored main navigation — full-width dock (no ambiguous “floating” hit target).
class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.storefront_outlined),
      selectedIcon: Icon(Icons.storefront_rounded),
      label: 'Market',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_rounded),
      selectedIcon: Icon(Icons.collections_bookmark_rounded),
      label: 'Collection',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Material(
        color: Color.lerp(
          scheme.surfaceContainerLow,
          scheme.primaryContainer,
          isLight ? 0.12 : 0.08,
        ),
        elevation: isLight ? 6 : 10,
        shadowColor: scheme.shadow.withValues(alpha: isLight ? 0.12 : 0.35),
        surfaceTintColor: scheme.primary.withValues(alpha: isLight ? 0.06 : 0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: Color.lerp(
                scheme.outlineVariant,
                scheme.primary,
                isLight ? 0.12 : 0.16,
              )!.withValues(alpha: isLight ? 0.55 : 0.45),
            ),
            NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: shell.goBranch,
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
