import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/home/widgets/release_lineup_strip.dart';
import 'package:blindbox_app/features/home/widgets/save_series_release_button.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Series release detail — image-first lineup browse and a single clear add CTA.
class DropDetailScreen extends StatelessWidget {
  const DropDetailScreen({super.key, required this.releaseId});

  final String releaseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final release = mockSeriesReleaseByDropId(releaseId);

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
      body: CustomScrollView(
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
                  const SizedBox(height: 20),
                  ReleaseLineupStrip(slots: release.lineup, accent: accent),
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
