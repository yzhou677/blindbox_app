import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/home/widgets/release_lineup_strip.dart';
import 'package:blindbox_app/features/home/widgets/save_series_release_button.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Series release detail — image-first lineup browse and a single clear add CTA.
class DropDetailScreen extends StatefulWidget {
  const DropDetailScreen({super.key, required this.releaseId});

  final String releaseId;

  @override
  State<DropDetailScreen> createState() => _DropDetailScreenState();
}

class _DropDetailScreenState extends State<DropDetailScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _peekController;
  int? _peekLineupIndex;

  @override
  void initState() {
    super.initState();
    _peekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _peekController.dispose();
    super.dispose();
  }

  void _openPeek(int index) {
    final release = mockSeriesReleaseByDropId(widget.releaseId);
    if (release == null || index < 0 || index >= release.lineup.length) return;

    final wasOpen = _peekLineupIndex != null;
    setState(() => _peekLineupIndex = index);
    if (wasOpen) {
      _peekController.value = 1;
    } else {
      _peekController.forward(from: 0);
    }
  }

  void _dismissPeek() {
    if (_peekLineupIndex == null) return;
    _peekController.reverse().then((_) {
      if (mounted) {
        setState(() => _peekLineupIndex = null);
      }
    });
  }

  Collectible _collectibleForPeek(SeriesRelease release, ReleaseLineupSlot slot) {
    final h = release.heroCollectible;
    return Collectible(
      id: '${release.dropId}-${slot.slotId}-peek',
      name: slot.name,
      series: h.series,
      brand: h.brand,
      ipLine: h.ipLine,
      releaseDate: h.releaseDate,
      imageUrl: slot.imageUrl!,
      shelfAccent: h.shelfAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final release = mockSeriesReleaseByDropId(widget.releaseId);

    if (release == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Release'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This release could not be found.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    final hero = release.heroCollectible;
    final accent = hero.shelfAccent ?? scheme.tertiaryContainer;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  backgroundColor: scheme.surface.withValues(alpha: 0.94),
                  surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.45),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  title: Text(
                    release.seriesName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.12,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _DetailHero(collectible: hero, accent: accent),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hero.name,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.28,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          release.seriesName,
                          style: textTheme.titleSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          release.brand,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${release.lineup.length} figures',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.02,
                          ),
                        ),
                        if (release.lineup.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          ReleaseLineupStrip(
                            slots: release.lineup,
                            accent: accent,
                            selectedIndex: _peekLineupIndex ?? -1,
                            onSlotTap: _openPeek,
                          ),
                        ],
                        const SizedBox(height: 16),
                        SaveSeriesReleaseButton(
                          release: release,
                          variant: SeriesReleaseShelfCtaVariant.filled,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_peekLineupIndex != null)
            Positioned.fill(
              child: _LineupPeekOverlay(
                animation: _peekController,
                release: release,
                slot: release.lineup[_peekLineupIndex!],
                accent: accent,
                onDismiss: _dismissPeek,
                peekCollectibleBuilder: _collectibleForPeek,
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft dim + floating card; does not replace the scroll body layout.
class _LineupPeekOverlay extends StatelessWidget {
  const _LineupPeekOverlay({
    required this.animation,
    required this.release,
    required this.slot,
    required this.accent,
    required this.onDismiss,
    required this.peekCollectibleBuilder,
  });

  final Animation<double> animation;
  final SeriesRelease release;
  final ReleaseLineupSlot slot;
  final Color accent;
  final VoidCallback onDismiss;
  final Collectible Function(SeriesRelease release, ReleaseLineupSlot slot) peekCollectibleBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final scale = Tween<double>(begin: 0.92, end: 1.0).animate(curved);

    return FadeTransition(
      opacity: animation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(
              color: scheme.shadow.withValues(alpha: 0.32),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: scale,
              child: GestureDetector(
                onTap: () {},
                child: _LineupPeekCard(
                  key: ValueKey<String>(slot.slotId),
                  release: release,
                  slot: slot,
                  accent: accent,
                  onClose: onDismiss,
                  peekCollectibleBuilder: peekCollectibleBuilder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupPeekCard extends StatelessWidget {
  const _LineupPeekCard({
    super.key,
    required this.release,
    required this.slot,
    required this.accent,
    required this.onClose,
    required this.peekCollectibleBuilder,
  });

  final SeriesRelease release;
  final ReleaseLineupSlot slot;
  final Color accent;
  final VoidCallback onClose;
  final Collectible Function(SeriesRelease release, ReleaseLineupSlot slot) peekCollectibleBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.88;

    final innerRadius = BorderRadius.circular(26);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW.clamp(0, 420)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: innerRadius,
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(scheme.shadow, accent, 0.12)!
                      .withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: innerRadius,
              child: Material(
                color: scheme.surfaceContainerLow,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 0.92,
                      child: ColoredBox(
                        color: scheme.surface.withValues(alpha: 0.55),
                        child: slot.isSecret || slot.imageUrl == null
                            ? _PeekSecretMat(accent: accent)
                            : CollectibleNetworkImage(
                                collectible: peekCollectibleBuilder(release, slot),
                                heroTag: null,
                                borderRadius: BorderRadius.zero,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.isSecret ? 'Secret' : slot.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            release.seriesName,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w500,
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
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: scheme.surface.withValues(alpha: 0.94),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              shadowColor: scheme.shadow.withValues(alpha: 0.2),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                tooltip: 'Close preview',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeekSecretMat extends StatelessWidget {
  const _PeekSecretMat({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(alpha: 0.96),
            Color.lerp(scheme.surfaceContainerLow, accent, 0.14)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.blur_on_rounded,
          size: 64,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.collectible,
    required this.accent,
  });

  final Collectible collectible;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final outerRadius = BorderRadius.circular(26);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        boxShadow: [
          BoxShadow(
            color: Color.lerp(scheme.shadow, accent, 0.1)!
                .withValues(alpha: brightness == Brightness.dark ? 0.42 : 0.1),
            blurRadius: 36,
            offset: const Offset(0, 18),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: outerRadius,
          side: BorderSide(
            color: accent.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.4),
                  scheme.surface.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: 0.88,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.72),
                    child: CollectibleNetworkImage(
                      collectible: collectible,
                      heroTag: collectible.heroImageTag,
                      borderRadius: BorderRadius.circular(14),
                      fit: BoxFit.contain,
                    ),
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
