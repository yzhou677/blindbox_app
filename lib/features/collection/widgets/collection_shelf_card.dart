import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/models/owned_collectible.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pinterest-style shelf tile: large image, soft mat, quantity badge, light typography.
class CollectionShelfCard extends StatelessWidget {
  const CollectionShelfCard({
    super.key,
    required this.owned,
    this.appear,
  });

  final OwnedCollectible owned;
  final CurvedAnimation? appear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final collectible = owned.collectible;
    final accent = collectible.shelfAccent ?? scheme.tertiaryContainer;
    final shadowAlpha = theme.brightness == Brightness.dark ? 0.36 : 0.1;
    final outerRadius = BorderRadius.circular(22);

    Widget card = Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: outerRadius,
        side: BorderSide(
          color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.34),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/detail/${collectible.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.38),
                            scheme.surface.withValues(alpha: 0.12),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.55),
                            child: CollectibleNetworkImage(
                              collectible: collectible,
                              borderRadius: BorderRadius.circular(12),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _QuantityBadge(
                      quantity: owned.quantity,
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collectible.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.12,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collectible.series,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                      letterSpacing: 0.08,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        boxShadow: [
          BoxShadow(
            color: Color.lerp(scheme.shadow, accent, 0.1)!.withValues(alpha: shadowAlpha + 0.03),
            blurRadius: 22,
            offset: const Offset(0, 12),
            spreadRadius: -5,
          ),
        ],
      ),
      child: card,
    );

    if (appear == null) return card;

    return AnimatedBuilder(
      animation: appear!,
      builder: (context, child) {
        final t = appear!.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: card,
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({
    required this.quantity,
    required this.accent,
  });

  final int quantity;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.55 : 0.72),
          scheme.surface.withValues(alpha: 0.2),
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          '×$quantity',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
    );
  }
}
