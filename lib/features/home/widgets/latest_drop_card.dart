import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/home/data/home_drop_rail_context.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/home/widgets/save_drop_to_shelf_button.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/shared/widgets/collectible_scan_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Series-first drop tile — packaging window, hierarchy, shelf save.
const double _kCardWidth = 252;
const double _kImageAspect = 1.02;

class LatestDropCard extends StatelessWidget {
  const LatestDropCard({super.key, required this.collectible});

  final Collectible collectible;

  String get _brandIpLine {
    final ip = collectible.ipLine?.trim();
    if (ip == null || ip.isEmpty) return collectible.brand;
    return '${collectible.brand} · $ip';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final outerRadius = CollectibleShape.shellRadius;
    final accent = collectible.shelfAccent ?? scheme.tertiaryContainer;

    return SizedBox(
      width: _kCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          boxShadow: CollectibleShelfShadow.productShell(context, accent: accent),
        ),
        child: Material(
          color: scheme.surface,
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                        padding: const EdgeInsets.all(10),
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
                  padding: const EdgeInsets.fromLTRB(14, 6, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CollectibleScanBadge(
                        icon: Icons.layers_outlined,
                        label: 'Blind-box series',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        collectible.series,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.18,
                          height: 1.15,
                          color: scheme.onSurface.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        collectible.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.02,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _brandIpLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.02,
                          height: 1.32,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: HomeDropRailContext.homeReleaseTooltip(collectible.releaseDate),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 16,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      HomeDropRailContext.homeReleaseWindowLabel(
                                        collectible.releaseDate,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SaveDropToShelfButton(collectible: collectible),
                        ],
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
