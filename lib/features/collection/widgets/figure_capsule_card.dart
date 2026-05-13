import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Collectible-sized capsule — owned / wish / missing read clearly at a glance.
class FigureCapsuleCard extends StatelessWidget {
  const FigureCapsuleCard({
    super.key,
    required this.figure,
    required this.tracked,
    required this.onTap,
  });

  final FigureDefinition figure;
  final TrackedFigure tracked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final owned = tracked.owned;
    final wish = tracked.wishlist;

    final borderColor = owned
        ? scheme.tertiary.withValues(alpha: 0.65)
        : wish
            ? scheme.primary.withValues(alpha: 0.55)
            : scheme.outlineVariant.withValues(alpha: 0.45);

    final matTint = owned
        ? scheme.tertiaryContainer.withValues(alpha: isDark ? 0.28 : 0.42)
        : wish
            ? scheme.primaryContainer.withValues(alpha: isDark ? 0.32 : 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final wishRibbon = wish && !owned;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: matTint,
            border: Border.all(color: borderColor, width: wishRibbon ? 2 : 1.2),
            boxShadow: [
              if (wishRibbon)
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: SizedBox(
            width: 118,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.55),
                            child: figure.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: figure.imageUrl!,
                                    fit: BoxFit.contain,
                                    fadeInDuration: const Duration(milliseconds: 220),
                                    errorWidget: (_, _, _) => _Initials(figure: figure, scheme: scheme),
                                  )
                                : _Initials(figure: figure, scheme: scheme),
                          ),
                        ),
                      ),
                      if (wishRibbon)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.shadow.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'WISH',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      if (owned)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 22,
                            color: scheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    figure.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.08,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    figure.isSecret ? '${figure.rarity} · chase' : figure.rarity,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.figure, required this.scheme});

  final FigureDefinition figure;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final letter = figure.name.isNotEmpty ? figure.name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
