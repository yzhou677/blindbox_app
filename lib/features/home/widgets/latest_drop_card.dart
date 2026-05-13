import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Slightly narrower + squatter image window = calmer first-feed beat.
const double _kCardWidth = 246;
const double _kImageAspect = 1.08;

class LatestDropCard extends StatelessWidget {
  const LatestDropCard({super.key, required this.collectible});

  final Collectible collectible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final outerRadius = CollectibleShape.shellRadius;
    final accent = collectible.shelfAccent ?? scheme.tertiaryContainer;
    final shadowAlpha = theme.brightness == Brightness.dark ? 0.38 : 0.11;

    return SizedBox(
      width: _kCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          boxShadow: [
            BoxShadow(
              color: Color.lerp(scheme.shadow, accent, 0.12)!
                  .withValues(alpha: shadowAlpha + 0.03),
              blurRadius: 22,
              offset: const Offset(0, 11),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: outerRadius,
            side: BorderSide(
              color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.38),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/home/detail/${collectible.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: _kImageAspect,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: CollectibleShape.matRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(scheme.surface, accent, 0.38)!
                                .withValues(alpha: theme.brightness == Brightness.dark ? 0.42 : 0.62),
                            accent.withValues(alpha: 0.4),
                            scheme.surface.withValues(alpha: 0.12),
                          ],
                          stops: const [0.0, 0.42, 1.0],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.22),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: ClipRRect(
                          borderRadius: CollectibleShape.insetRadius,
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.72),
                            child: CollectibleNetworkImage(
                              collectible: collectible,
                              heroTag: collectible.heroImageTag,
                              borderRadius: CollectibleShape.insetRadius,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          avatar: Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.82),
                          ),
                          label: Text(
                            collectible.series,
                            style: textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.14,
                              fontWeight: FontWeight.w600,
                              height: 1.12,
                            ),
                          ),
                          backgroundColor: Color.lerp(
                            scheme.primaryContainer,
                            scheme.secondaryContainer,
                            0.32,
                          )!.withValues(alpha: 0.58),
                          side: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        collectible.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.16,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        collectible.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.03,
                          height: 1.32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.28 : 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          collectible.releaseDateLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
