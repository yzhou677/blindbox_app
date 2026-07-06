import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/recommendations/application/recommendation_readiness_provider.dart';
import 'package:blindbox_app/features/recommendations/application/recommendations_provider.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/presentation/for_you_copy.dart';
import 'package:blindbox_app/features/recommendations/widgets/for_you_series_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForYouSection extends ConsumerStatefulWidget {
  const ForYouSection({super.key});

  @override
  ConsumerState<ForYouSection> createState() => _ForYouSectionState();
}

class _ForYouSectionState extends ConsumerState<ForYouSection> {
  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(recommendationReadinessProvider);
    if (!ready) return const SizedBox.shrink();

    final recommendationsAsync = ref.watch(recommendationsProvider);
    final Widget? sectionBody = recommendationsAsync.when<Widget?>(
      loading: () => _ForYouLoadingRail(),
      error: (error, stackTrace) => null,
      data: (result) {
        // Intentionally hide the section when no recommendations are available.
        // Discover remains useful via other content rails; showing an empty
        // personalization section would add unnecessary UI noise.
        if (result.items.isEmpty) return null;
        return _ForYouLoadedRail(
          items: result.items,
          showFirstUnlockBadge: ref.watch(forYouFirstUnlockBadgeProvider),
          onOpenSeries: _openSeriesPreview,
          onDismissFirstUnlock: () => dismissForYouFirstUnlockBadge(ref),
        );
      },
    );

    return _ForYouSectionReveal(
      show: sectionBody != null,
      child: sectionBody ?? const SizedBox.shrink(),
    );
  }

  Future<void> _openSeriesPreview(BuildContext context, String seriesId) async {
    final template = ref.read(catalogSeriesTemplateProvider(seriesId));
    if (template == null) return;

    final notifier = ref.read(collectionNotifierProvider.notifier);
    final snap = ref.read(collectionNotifierProvider);
    final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
      snapshot: snap,
      layout: CollectionSeriesShelfCtaLayout.previewSticky,
      catalogTemplateId: seriesId,
      seriesName: template.name,
      brandName: template.brand,
      taxonomyBrandId: template.taxonomyBrandId,
      taxonomyIpId: template.taxonomyIpId,
    );

    await showCollectibleBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
      builder: (ctx, scroll) {
        return CatalogSeriesPreviewSheet(
          series: template,
          shelfCta: shelfCta,
          onAdd: () => commitCatalogSeriesToShelf(notifier, template),
        );
      },
    );
  }
}

/// Gentle fade + vertical expand when For You first becomes visible.
class _ForYouSectionReveal extends StatefulWidget {
  const _ForYouSectionReveal({
    required this.show,
    required this.child,
  });

  final bool show;
  final Widget child;

  @override
  State<_ForYouSectionReveal> createState() => _ForYouSectionRevealState();
}

class _ForYouSectionRevealState extends State<_ForYouSectionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.crossfade,
    );
    _fade = CollectibleMotion.curved(_controller);
    _expand = CurvedAnimation(
      parent: _controller,
      curve: CollectibleMotion.easeOut,
    );
    if (widget.show) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ForYouSectionReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward(from: 0);
    } else if (!widget.show) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _expand.value.clamp(0.001, 1.0),
            child: Opacity(
              opacity: _fade.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ForYouLoadedRail extends StatelessWidget {
  const _ForYouLoadedRail({
    required this.items,
    required this.showFirstUnlockBadge,
    required this.onOpenSeries,
    required this.onDismissFirstUnlock,
  });

  final List<RecommendationItem> items;
  final bool showFirstUnlockBadge;
  final Future<void> Function(BuildContext context, String seriesId) onOpenSeries;
  final VoidCallback onDismissFirstUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (showFirstUnlockBadge && notification is ScrollUpdateNotification) {
          onDismissFirstUnlock();
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectibleSectionHeader(
            title: ForYouCopy.sectionTitle,
            subtitle: showFirstUnlockBadge
                ? ForYouCopy.firstUnlockSubtitle
                : ForYouCopy.sectionSubtitle,
            titleAccessory: showFirstUnlockBadge
                ? _FirstUnlockBadge(label: ForYouCopy.firstUnlockBadge)
                : null,
          ),
          const SizedBox(height: FeedRhythm.sectionHeaderToRail),
          ColoredBox(
            color: HomeSectionZones.trendingSeriesMat(scheme, brightness),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: SizedBox(
                height: FeedRhythm.homeSeriesRailHeight,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(width: FeedRhythm.horizontalRailCardGap),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ForYouSeriesCard(
                      item: item,
                      onTap: () => onOpenSeries(context, item.seriesId),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstUnlockBadge extends StatelessWidget {
  const _FirstUnlockBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ForYouLoadingRail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(title: ForYouCopy.sectionTitle),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        ColoredBox(
          color: HomeSectionZones.trendingSeriesMat(scheme, brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: SizedBox(
              height: FeedRhythm.homeSeriesRailHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, index) =>
                    SizedBox(width: FeedRhythm.horizontalRailCardGap),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: FeedRhythm.homeSeriesRailCardWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: AppRadii.shellRadius,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
