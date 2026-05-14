import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Mini blind-box / shelf card — collected, wish list, and open-slot states.
class FigureCapsuleCard extends StatefulWidget {
  const FigureCapsuleCard({
    super.key,
    required this.figure,
    required this.tracked,
    required this.onTap,
  });

  final ShelfFigure figure;
  final TrackedFigure tracked;
  final VoidCallback onTap;

  @override
  State<FigureCapsuleCard> createState() => _FigureCapsuleCardState();
}

class _FigureCapsuleCardState extends State<FigureCapsuleCard> with TickerProviderStateMixin {
  late AnimationController _press;
  AnimationController? _sheen;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _initSheen();
  }

  void _initSheen() {
    if (widget.figure.isSecret) {
      _sheen ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
        ..repeat();
    }
  }

  @override
  void didUpdateWidget(FigureCapsuleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.figure.isSecret != widget.figure.isSecret) {
      if (widget.figure.isSecret) {
        _sheen ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
          ..repeat();
      } else {
        _sheen?.dispose();
        _sheen = null;
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _sheen?.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    _press.forward(from: 0).then((_) {
      if (mounted) _press.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final owned = widget.tracked.owned;
    final wish = widget.tracked.wishlist;
    final missing = !owned && !wish;

    final Color matTint;
    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow> shadows;
    final Gradient? cardFaceGradient;

    if (owned) {
      matTint = Color.lerp(
            scheme.primaryContainer,
            const Color(0xFFFFF6E5),
            isDark ? 0.14 : 0.42,
          )!
          .withValues(alpha: isDark ? 0.42 : 0.58);
      borderColor = Color.lerp(scheme.primary, const Color(0xFFC9A227), 0.28)!
          .withValues(alpha: isDark ? 0.58 : 0.68);
      borderWidth = 1.45;
      shadows = [
        BoxShadow(
          color: const Color(0xFFE8C547).withValues(alpha: isDark ? 0.18 : 0.14),
          blurRadius: 18,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
      cardFaceGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(matTint, const Color(0xFFFFFBF0), isDark ? 0.22 : 0.38)!,
          matTint,
          Color.lerp(matTint, const Color(0xFFE8C547), 0.14)!,
        ],
        stops: const [0.0, 0.48, 1.0],
      );
    } else if (wish) {
      matTint = Color.lerp(
            scheme.primaryContainer,
            const Color(0xFFFFF0F6),
            isDark ? 0.22 : 0.58,
          )!
          .withValues(alpha: isDark ? 0.38 : 0.62);
      borderColor = const Color(0xFFE879A6).withValues(alpha: isDark ? 0.58 : 0.78);
      borderWidth = 1.7;
      shadows = [
        BoxShadow(
          color: const Color(0xFFD896C8).withValues(alpha: 0.22),
          blurRadius: 22,
          spreadRadius: -6,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: const Color(0xFFFFE4F0).withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
      cardFaceGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(matTint, const Color(0xFFFFFBFE), 0.45)!,
          matTint,
          Color.lerp(matTint, const Color(0xFFE8B4D4), 0.2)!,
        ],
        stops: const [0.0, 0.52, 1.0],
      );
    } else {
      matTint = scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.5);
      borderColor = scheme.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.48);
      borderWidth = 1.15;
      shadows = [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
      cardFaceGradient = null;
    }

    final tilt = ((widget.figure.id.hashCode % 5) - 2) * 0.012;

    return Transform.rotate(
      angle: tilt,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: scheme.primary.withValues(alpha: 0.07),
          highlightColor: scheme.primary.withValues(alpha: 0.03),
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_press.value);
              final scale = 1.0 - (0.028 * t);
              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: cardFaceGradient,
                color: cardFaceGradient == null ? matTint : null,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: shadows,
              ),
              child: SizedBox(
                width: 130,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(
                                    scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                                    child: child,
                                  ),
                                );
                              },
                              child: _ArtWindow(
                                key: ValueKey<String>('${widget.figure.id}-${owned}_${wish}_$missing'),
                                missing: missing,
                                scheme: scheme,
                                figure: widget.figure,
                                sheen: _sheen,
                              ),
                            ),
                          ),
                          if (wish && !owned)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: _WishRibbon(textTheme: textTheme),
                            ),
                          if (owned)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: _OwnedSeal(scheme: scheme),
                            ),
                          if (missing)
                            Positioned(
                              left: 5,
                              bottom: 5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surface.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Text(
                                    'empty slot',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.48),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Text(
                        widget.figure.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          height: 1.15,
                          color: missing
                              ? scheme.onSurface.withValues(alpha: 0.68)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.figure.isSecret ? '${widget.figure.rarity} · chase' : widget.figure.rarity,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: missing ? 0.52 : 0.78),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtWindow extends StatelessWidget {
  const _ArtWindow({
    super.key,
    required this.missing,
    required this.scheme,
    required this.figure,
    required this.sheen,
  });

  final bool missing;
  final ColorScheme scheme;
  final ShelfFigure figure;
  final AnimationController? sheen;

  @override
  Widget build(BuildContext context) {
    final sheenCtrl = sheen;
    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: missing ? 0.5 : 0.72),
                  Color.lerp(scheme.surfaceContainerLow, scheme.surface, 0.5)!
                      .withValues(alpha: missing ? 0.55 : 0.85),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: missing
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      scheme.onSurface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.07),
                      BlendMode.srcATop,
                    ),
                    child: _FigureThumb(figure: figure, scheme: scheme),
                  )
                : _FigureThumb(figure: figure, scheme: scheme),
          ),
          if (missing)
            CustomPaint(
              painter: _DashedSlotBorderPainter(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
                radius: 15,
              ),
            ),
          if (figure.isSecret && sheenCtrl != null)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: sheenCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SecretSheenPainter(progress: sheenCtrl.value),
                    );
                  },
                ),
              ),
            ),
          if (figure.isSecret)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    width: 1.25,
                    color: Color.lerp(const Color(0xFFE8C547), scheme.primary, 0.45)!
                        .withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: missing ? 0.04 : 0.07),
            blurRadius: missing ? 4 : 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: missing ? 0.35 : 0.22),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 0.8,
            ),
          ),
          child: inner,
        ),
      ),
    );
  }
}

class _SecretSheenPainter extends CustomPainter {
  _SecretSheenPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shift = progress * 2.4 - 0.4;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1.1 + shift, -0.6),
        end: Alignment(0.2 + shift, 1.1),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.09),
          const Color(0xFFE8D5FF).withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.075),
          Colors.transparent,
        ],
        stops: const [0.0, 0.38, 0.5, 0.62, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.softLight;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _SecretSheenPainter oldDelegate) => oldDelegate.progress != progress;
}

class _DashedSlotBorderPainter extends CustomPainter {
  _DashedSlotBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawDashedPath(canvas, path, paint, dash: 5, gap: 4);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = d + dash;
        final extract = metric.extractPath(d, next.clamp(0.0, metric.length));
        canvas.drawPath(extract, paint);
        d = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedSlotBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _FigureThumb extends StatelessWidget {
  const _FigureThumb({required this.figure, required this.scheme});

  final ShelfFigure figure;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (figure.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: CachedNetworkImage(
          imageUrl: figure.imageUrl!,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 280),
          errorWidget: (context, url, error) => CollectibleFigurePlaceholder(
            name: figure.name,
            seedKey: figure.id,
            isSecret: figure.isSecret,
          ),
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
            const Color(0xFFFFB8D9).withValues(alpha: 0.98),
            const Color(0xFFE879A6).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE879A6).withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_fix_high_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Wish list',
              style: textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.12,
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
        gradient: LinearGradient(
          colors: [
            Color.lerp(scheme.primary, const Color(0xFFE8C547), 0.38)!,
            Color.lerp(scheme.primary, const Color(0xFFB8860B), 0.22)!,
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8C547).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.workspace_premium_rounded, size: 17, color: scheme.onTertiaryContainer),
      ),
    );
  }
}
