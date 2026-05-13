import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
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
    final missing = !owned && !wish;

    // Owned: warm “home on the shelf”
    // Wishlist: soft rose — emotionally “still hunting”
    // Missing: quiet open-slot energy
    final Color matTint;
    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow> shadows;

    if (owned) {
      matTint = Color.lerp(
            scheme.tertiaryContainer,
            const Color(0xFFFFF8E8),
            isDark ? 0.12 : 0.38,
          )!
          .withValues(alpha: isDark ? 0.38 : 0.52);
      borderColor = Color.lerp(scheme.tertiary, const Color(0xFFC9A227), 0.35)!
          .withValues(alpha: isDark ? 0.55 : 0.62);
      borderWidth = 1.35;
      shadows = [
        BoxShadow(
          color: scheme.tertiary.withValues(alpha: isDark ? 0.22 : 0.12),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ];
    } else if (wish) {
      matTint = Color.lerp(
            scheme.primaryContainer,
            const Color(0xFFFFE8F0),
            isDark ? 0.2 : 0.55,
          )!
          .withValues(alpha: isDark ? 0.34 : 0.58);
      borderColor = const Color(0xFFE879A6).withValues(alpha: isDark ? 0.55 : 0.72);
      borderWidth = 1.65;
      shadows = [
        BoxShadow(
          color: const Color(0xFFE879A6).withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    } else {
      matTint = scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.38 : 0.48);
      borderColor = scheme.outlineVariant.withValues(alpha: isDark ? 0.38 : 0.42);
      borderWidth = 1.1;
      shadows = [];
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: scheme.primary.withValues(alpha: 0.08),
        highlightColor: scheme.primary.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: matTint,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: SizedBox(
            width: 122,
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
                            color: scheme.surface.withValues(alpha: missing ? 0.42 : 0.62),
                            child: missing
                                ? ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.06),
                                      BlendMode.srcATop,
                                    ),
                                    child: _FigureThumb(figure: figure, scheme: scheme),
                                  )
                                : _FigureThumb(figure: figure, scheme: scheme),
                          ),
                        ),
                      ),
                      if (wish && !owned)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _WishRibbon(textTheme: textTheme),
                        ),
                      if (owned)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _OwnedSeal(scheme: scheme),
                        ),
                      if (missing)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Text(
                            'slot',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              height: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    figure.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.08,
                      height: 1.15,
                      color: missing
                          ? scheme.onSurface.withValues(alpha: 0.72)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    figure.isSecret ? '${figure.rarity} · chase' : figure.rarity,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: missing ? 0.55 : 0.78),
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

class _FigureThumb extends StatelessWidget {
  const _FigureThumb({required this.figure, required this.scheme});

  final FigureDefinition figure;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (figure.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: figure.imageUrl!,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 240),
        errorWidget: (context, url, error) => CollectibleFigurePlaceholder(
          name: figure.name,
          seedKey: figure.id,
          isSecret: figure.isSecret,
        ),
      );
    }
    return CollectibleFigurePlaceholder(
      name: figure.name,
      seedKey: figure.id,
      isSecret: figure.isSecret,
    );
  }
}

class _WishRibbon extends StatelessWidget {
  const _WishRibbon({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF8FB4).withValues(alpha: 0.95),
            const Color(0xFFE879A6).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE879A6).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Hunt',
              style: textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedSeal extends StatelessWidget {
  const _OwnedSeal({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(scheme.tertiary, const Color(0xFFC9A227), 0.25),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(Icons.home_rounded, size: 18, color: scheme.onTertiaryContainer),
      ),
    );
  }
}
