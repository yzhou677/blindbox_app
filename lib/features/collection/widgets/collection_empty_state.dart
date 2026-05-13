import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Polished empty shelf — cozy, visual-first, not an error state.
class CollectionEmptyState extends StatelessWidget {
  const CollectionEmptyState({super.key, this.onAddLine});

  /// Opens add-from-catalog or custom line flow.
  final VoidCallback? onAddLine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.secondaryContainer.withValues(alpha: isDark ? 0.35 : 0.65),
                  scheme.tertiaryContainer.withValues(alpha: isDark ? 0.22 : 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 52,
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your shelf is waiting',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.35,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add suggested lines or create your own — everything stays on your device for now.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (onAddLine != null) ...[
                    FilledButton(
                      onPressed: onAddLine,
                      child: const Text('Add a line'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: const Text('Browse drops'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
