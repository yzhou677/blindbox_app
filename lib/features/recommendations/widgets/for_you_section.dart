import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/features/recommendations/application/recommendation_readiness_provider.dart';
import 'package:blindbox_app/features/recommendations/application/recommendations_provider.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_repository.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
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

/// Keeps the last rendered rail during [recommendationsProvider] refresh.
@visibleForTesting
RecommendationResult? resolveForYouDisplayResult({
  required AsyncValue<RecommendationResult> recommendationsAsync,
  required RecommendationResult? previousResult,
}) {
  return recommendationsAsync.when(
    data: (result) => result,
    loading: () => previousResult,
    error: (_, stackTrace) => previousResult,
  );
}

/// Display projection for For You — filters owned series for render only.
/// Does not mutate the underlying [recommendationsProvider] result.
@visibleForTesting
RecommendationResult? visibleForYouResult({
  required RecommendationResult? displayResult,
  required PreferenceSignals signals,
}) {
  if (displayResult == null) return null;
  return excludeOwnedCatalogSeries(displayResult, signals);
}

class _ForYouSectionState extends ConsumerState<ForYouSection> {
  RecommendationResult? _previousResult;

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(recommendationReadinessProvider);
    if (!ready) return const SizedBox.shrink();

    ref.listen<AsyncValue<RecommendationResult>>(recommendationsProvider, (
      _,
      next,
    ) {
      next.whenData((result) {
        if (_previousResult != result) {
          setState(() => _previousResult = result);
        }
      });
    });

    final recommendationsAsync = ref.watch(recommendationsProvider);
    final signals = extractSignals(ref.watch(collectionNotifierProvider));
    final displayResult = visibleForYouResult(
      displayResult: resolveForYouDisplayResult(
        recommendationsAsync: recommendationsAsync,
        previousResult: _previousResult,
      ),
      signals: signals,
    );

    final Widget? sectionBody = _buildSectionBody(
      recommendationsAsync: recommendationsAsync,
      displayResult: displayResult,
    );

    return _ForYouSectionReveal(
      show: sectionBody != null,
      child: sectionBody ?? const SizedBox.shrink(),
    );
  }

  Widget? _buildSectionBody({
    required AsyncValue<RecommendationResult> recommendationsAsync,
    required RecommendationResult? displayResult,
  }) {
    if (displayResult != null) {
      // Intentionally hide the section when no recommendations are available.
      if (displayResult.items.isEmpty) return null;
      return _ForYouLoadedRail(
        items: displayResult.items,
        showFirstUnlockBadge: ref.watch(forYouFirstUnlockBadgeProvider),
        onOpenSeries: _openSeriesPreview,
        onDismissFirstUnlock: () => dismissForYouFirstUnlockBadge(ref),
      );
    }

    if (recommendationsAsync.isLoading) {
      return _ForYouLoadingRail();
    }

    return null;
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
            titleAccessory: const _ForYouTitleIcon(),
            trailing: showFirstUnlockBadge
                ? _FirstUnlockBadge(label: ForYouCopy.firstUnlockBadge)
                : null,
          ),
          const SizedBox(height: FeedRhythm.sectionHeaderToRail),
          SizedBox(
            height: FeedRhythm.marketChasersRailHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
        ],
      ),
    );
  }
}

class _ForYouTitleIcon extends StatelessWidget {
  const _ForYouTitleIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.auto_awesome_outlined,
      size: 20,
      color: scheme.primary.withValues(alpha: 0.82),
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
    final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(
          title: ForYouCopy.sectionTitle,
          titleAccessory: _ForYouTitleIcon(),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        SizedBox(
          height: FeedRhythm.marketChasersRailHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (context, index) =>
                SizedBox(width: FeedRhythm.horizontalRailCardGap),
            itemBuilder: (context, index) {
              return SizedBox(
                width: kForYouRailCardWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.matRadius,
                              color: fill,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 88,
                          height: 10,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
