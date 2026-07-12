import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_glyph.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_ceremony_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen Collector Type reveal ceremony — event only, not the hero card.
///
/// Frosted blur, then one hero beat (mascot + title + flavor together), a short
/// pause to absorb the identity, then Continue — held long enough to notice.
class CollectorTypeRevealCeremonyOverlay extends StatefulWidget {
  const CollectorTypeRevealCeremonyOverlay({
    super.key,
    required this.identity,
    required this.isFirstReveal,
    required this.onFinished,
  });

  final CollectorTypeIdentity identity;
  final bool isFirstReveal;
  final VoidCallback onFinished;

  @override
  State<CollectorTypeRevealCeremonyOverlay> createState() =>
      _CollectorTypeRevealCeremonyOverlayState();
}

class _CollectorTypeRevealCeremonyOverlayState
    extends State<CollectorTypeRevealCeremonyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _blurCache = CeremonyBlurCache();
  var _started = false;
  var _finished = false;

  Duration get _duration => widget.isFirstReveal
      ? CollectibleMotion.collectorTypeRevealCeremonyFirst
      : CollectibleMotion.collectorTypeRevealCeremonyChange;

  bool get _first => widget.isFirstReveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _beginPlayback();
    });
  }

  void _beginPlayback() {
    if (_started || !mounted) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _finish();
      return;
    }

    HapticFeedback.lightImpact();
    _controller.addStatusListener(_onStatus);
    unawaited(_controller.forward(from: 0));
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _controller.removeStatusListener(_onStatus);
    // Timeline already includes Continue dwell — dismiss only after that.
    _finish();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  void _onBackgroundTap() {
    if (!CollectorTypeRevealCeremonyTiming.canDismiss(
      _controller.value,
      first: _first,
    )) {
      return;
    }
    _controller.stop();
    _finish();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final archetype = widget.identity.archetype;
    final accent = archetype.accentFor(Theme.of(context).brightness);
    final intro = _first
        ? CollectorTypeCopy.revealCeremonyFirstIntro
        : CollectorTypeCopy.revealCeremonyEvolvedIntro;

    final frostColor = isDark
        ? const Color(0xFF2A2A2E).withValues(alpha: 1)
        : const Color(0xFFF4F4F6).withValues(alpha: 1);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value.clamp(0.0, 1.0);
          final blur = CollectorTypeRevealCeremonyTiming.blurSigma(
            t,
            first: _first,
          );
          final frost = CollectorTypeRevealCeremonyTiming.frostOpacity(
            t,
            first: _first,
          );
          final introOp = CollectorTypeRevealCeremonyTiming.intro(
            t,
            first: _first,
          );
          final heroOp = CollectorTypeRevealCeremonyTiming.hero(
            t,
            first: _first,
          );
          final mascotScale = CollectorTypeRevealCeremonyTiming.mascotScale(
            t,
            first: _first,
          );
          final ctaOp = CollectorTypeRevealCeremonyTiming.cta(t, first: _first);
          final ctaDy = CollectorTypeRevealCeremonyTiming.ctaSlide(
            t,
            first: _first,
          );

          return PopScope(
            canPop: false,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onBackgroundTap,
                    child: ClipRect(
                      child: BackdropFilter(
                        key: const Key('collector_type_reveal_ceremony_backdrop'),
                        filter: blur <= 0.05
                            ? ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01)
                            : _blurCache.forSigma(blur),
                        child: ColoredBox(
                          color: frostColor.withValues(alpha: frost),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.12),
                          radius: 0.9,
                          colors: [
                            accent.withValues(alpha: 0.10 * heroOp),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: introOp,
                              child: Text(
                                intro,
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.62,
                                  ),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.08,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            SizedBox(height: _first ? 28 : 22),
                            // One hero: mascot + title + flavor share opacity.
                            Opacity(
                              opacity: heroOp,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.scale(
                                    scale: mascotScale,
                                    child: CollectorTypeGlyph(
                                      archetype: archetype,
                                      size: _first ? 128 : 112,
                                    ),
                                  ),
                                  SizedBox(height: _first ? 28 : 20),
                                  Text(
                                    archetype.displayName,
                                    textAlign: TextAlign.center,
                                    style:
                                        CollectibleTypography.seriesHeroTitle(
                                      textTheme,
                                      scheme,
                                    ).copyWith(
                                      fontSize: _first ? 32 : 28,
                                      letterSpacing: -0.55,
                                      height: 1.1,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.94,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    archetype.flavorText,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.insightsFlavor(
                                      textTheme,
                                      scheme,
                                    ).copyWith(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: _first ? 28 : 22),
                            Opacity(
                              opacity: ctaOp,
                              child: Transform.translate(
                                offset: Offset(0, ctaDy),
                                child: TextButton(
                                  key: const Key(
                                    'collector_type_reveal_ceremony_cta',
                                  ),
                                  onPressed: ctaOp > 0.55 ? _finish : null,
                                  child: Text(
                                    CollectorTypeCopy.revealCeremonyContinue,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: scheme.primary.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
