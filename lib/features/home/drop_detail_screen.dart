import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/release_lineup_strip.dart';
import 'package:blindbox_app/features/home/widgets/save_series_release_button.dart';
import 'package:blindbox_app/features/home/widgets/series_release_cover_image.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Series release detail — lineup strip opens the shared figure gallery.
class DropDetailScreen extends ConsumerWidget {
  const DropDetailScreen({super.key, required this.releaseId});

  final String releaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final release = ref.watch(seriesReleaseLookupProvider)(releaseId);

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
    final galleryItems = catalogGalleryItemsFromSeriesRelease(release);

    void openGallery(int index) {
      showCatalogFigureGallery(
        context,
        items: galleryItems,
        initialIndex: index,
        seriesTitle: release.seriesName,
      );
    }

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
              style: CollectibleTypography.seriesHeroTitle(textTheme, scheme)
                  .copyWith(fontSize: 18),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _DetailHero(release: release, accent: accent),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SeriesHeroMetaBlock(
                    brand: release.brand,
                    ipLine: release.ipLine?.trim() ?? '',
                    trailingMeta: release.lineup.isEmpty
                        ? null
                        : release.lineup.length == 1
                            ? '1 figure'
                            : '${release.lineup.length} figures',
                  ),
                  if (release.lineup.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ReleaseLineupStrip(
                      slots: release.lineup,
                      accent: accent,
                      onSlotTap: openGallery,
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
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.release,
    required this.accent,
  });

  final SeriesRelease release;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final outerRadius = AppRadii.spotlightRadius;

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
          padding: const EdgeInsets.all(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadii.matRadius,
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
              padding: const EdgeInsets.all(6),
              child: AspectRatio(
                aspectRatio: CatalogImageDisplaySpec.aspectRatioFor(
                      CatalogImageDisplayMode.seriesCoverHero,
                    ) ??
                    1.0,
                child: ClipRRect(
                  borderRadius: AppRadii.insetRadius,
                  child: SeriesReleaseCoverImage(
                    release: release,
                    heroTag: SeriesReleaseCoverImage.heroTagFor(release),
                    borderRadius: BorderRadius.zero,
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
