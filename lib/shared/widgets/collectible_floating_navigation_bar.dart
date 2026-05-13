import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:flutter/material.dart';

/// Compact floating shelf for the main tab bar — layered surface, soft indicator.
class CollectibleFloatingNavigationBar extends StatelessWidget {
  const CollectibleFloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final base = Color.lerp(
      scheme.surfaceContainerLow,
      scheme.primaryContainer,
      isLight ? 0.16 : 0.11,
    )!;
    final sheen = Color.lerp(
      scheme.surface,
      scheme.primaryContainer,
      isLight ? 0.38 : 0.2,
    )!;

    final radius = BorderRadius.circular(CollectibleShape.shell);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Color.lerp(
              scheme.outlineVariant,
              scheme.primary,
              isLight ? 0.12 : 0.16,
            )!.withValues(alpha: isLight ? 0.4 : 0.34),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(sheen, base, 0.35)!,
              base,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: isLight ? 0.07 : 0.26),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            height: 64,
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: Color.lerp(
              scheme.primaryContainer,
              scheme.primary,
              isLight ? 0.24 : 0.3,
            )!.withValues(alpha: isLight ? 0.64 : 0.46),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
