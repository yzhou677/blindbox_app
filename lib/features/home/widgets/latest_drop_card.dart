import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _kCardWidth = 276;
const double _kImageAspect = 0.88;

class LatestDropCard extends StatelessWidget {
  const LatestDropCard({super.key, required this.collectible});

  final Collectible collectible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final outerRadius = BorderRadius.circular(26);
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
                  .withValues(alpha: shadowAlpha + 0.04),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -6,
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
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.42),
                            scheme.surface.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.65),
                            child: CollectibleNetworkImage(
                              collectible: collectible,
                              heroTag: collectible.heroImageTag,
                              borderRadius: BorderRadius.circular(12),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
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
                            size: 16,
                            color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                          ),
                          label: Text(
                            collectible.series.toUpperCase(),
                            style: textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.55,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.55),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 8),
                      Text(
                        collectible.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.28 : 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          collectible.releaseDateLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.15,
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
