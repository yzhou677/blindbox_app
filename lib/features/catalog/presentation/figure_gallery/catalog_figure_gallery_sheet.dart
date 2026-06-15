import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_page.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_precache.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_discover_expand_panel.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the shared fullscreen figure gallery (swipe, drag down, tap outside art to close).
///
/// All product surfaces must call this — Home release detail, Collection series sheet,
/// and catalog add/preview flows. Do not push a separate gallery route.
Future<void> showCatalogFigureGallery(
  BuildContext context, {
  required List<CatalogFigureGalleryItem> items,
  required int initialIndex,
  String? seriesTitle,
}) {
  if (items.isEmpty) return Future<void>.value();
  final index = initialIndex.clamp(0, items.length - 1);

  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: CollectibleImmersion.galleryBarrier,
      transitionDuration: CollectibleMotion.galleryOpen,
      reverseTransitionDuration: CollectibleMotion.galleryClose,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return CatalogFigureGallerySheet(
          items: items,
          initialIndex: index,
          seriesTitle: seriesTitle,
          routeAnimation: animation,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CollectibleMotion.curved(animation);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: CollectibleMotion.galleryEnterScale,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

const Color _kGalleryForeground = Color(0xFFF5F5F5);

/// Fullscreen swipeable gallery with blurred scrim, close control, and drag dismiss.
class CatalogFigureGallerySheet extends StatefulWidget {
  const CatalogFigureGallerySheet({
    super.key,
    required this.items,
    required this.initialIndex,
    this.seriesTitle,
    this.routeAnimation,
  });

  final List<CatalogFigureGalleryItem> items;
  final int initialIndex;
  final String? seriesTitle;
  final Animation<double>? routeAnimation;

  @override
  State<CatalogFigureGallerySheet> createState() =>
      _CatalogFigureGallerySheetState();
}

class _CatalogFigureGallerySheetState extends State<CatalogFigureGallerySheet> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CatalogFigureGalleryPrecache.schedule(
        context,
        widget.items,
        _currentIndex,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageSettled(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    CatalogFigureGalleryPrecache.schedule(context, widget.items, index);
  }

  void _dismiss() {
    Navigator.of(context).pop();
  }

  String? _figureMetaLine(CatalogFigureGalleryItem item) {
    final rarity = item.rarityLabel?.trim();
    if (item.isSecret) {
      if (rarity != null && rarity.isNotEmpty) {
        return '$rarity · Secret';
      }
      return 'Secret';
    }
    return rarity != null && rarity.isNotEmpty ? rarity : null;
  }

  String? _captionSecondaryLine({
    required String? metaLine,
    required String? seriesTitle,
  }) {
    final series = seriesTitle?.trim();
    final meta = metaLine?.trim();
    if (series != null && series.isNotEmpty) {
      if (meta != null && meta.isNotEmpty) return '$series · $meta';
      return series;
    }
    return meta;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final item = widget.items[_currentIndex];
    final metaLine = _figureMetaLine(item);
    final captionSecondary = _captionSecondaryLine(
      metaLine: metaLine,
      seriesTitle: widget.seriesTitle,
    );
    final routeFade = widget.routeAnimation?.value ?? 1.0;

    return PopScope(
      canPop: true,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: routeFade,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: ColoredBox(
                  color: CollectibleImmersion.galleryBarrier,
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismiss,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GalleryDragHandle(onDismiss: _dismiss),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Close',
                              onPressed: _dismiss,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _kGalleryForeground,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${_currentIndex + 1} of ${widget.items.length}',
                                textAlign: TextAlign.center,
                                style: textTheme.labelMedium?.copyWith(
                                  color: _kGalleryForeground.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      if (widget.items.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _GalleryPageIndicator(
                            count: widget.items.length,
                            index: _currentIndex,
                          ),
                        ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: widget.items.length,
                          onPageChanged: _onPageSettled,
                          physics: const BouncingScrollPhysics(),
                          allowImplicitScrolling: true,
                          itemBuilder: (context, index) {
                            return CollectiblePresenceFade(
                              key: ValueKey<String>(
                                'gallery-presence:${widget.items[index].id}',
                              ),
                              child: CatalogFigureGalleryPage(
                                key: ValueKey<String>(
                                  'gallery-page:${widget.items[index].id}',
                                ),
                                item: widget.items[index],
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                        child: AnimatedSwitcher(
                          duration: CollectibleMotion.crossfade,
                          switchInCurve: CollectibleMotion.standard,
                          switchOutCurve: Curves.easeIn,
                          child: Column(
                            key: ValueKey<String>(item.id),
                            children: [
                              Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: CollectibleTypography.figureCaption(
                                  textTheme,
                                  Theme.of(context).colorScheme,
                                ).copyWith(color: _kGalleryForeground),
                              ),
                              _GalleryMarketInformationAccordion(
                                figureId: item.id,
                              ),
                              if (captionSecondary != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  captionSecondary,
                                  textAlign: TextAlign.center,
                                  style: CollectibleTypography.figureMeta(
                                    textTheme,
                                    Theme.of(context).colorScheme,
                                  ).copyWith(
                                    color: _kGalleryForeground.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Discover gallery market accordion — disclosure row is the only tap target.
///
/// [CatalogFigureGalleryItem.id] is the canonical catalog figure id.
class _GalleryMarketInformationAccordion extends ConsumerStatefulWidget {
  const _GalleryMarketInformationAccordion({required this.figureId});

  final String figureId;

  @override
  ConsumerState<_GalleryMarketInformationAccordion> createState() =>
      _GalleryMarketInformationAccordionState();
}

class _GalleryMarketInformationAccordionState
    extends ConsumerState<_GalleryMarketInformationAccordion> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _GalleryMarketInformationAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.figureId != widget.figureId) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnapshot = ref.watch(marketSnapshotProvider(widget.figureId));
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return asyncSnapshot.when(
      data: (snapshot) {
        if (snapshot == null) {
          return const SizedBox.shrink();
        }

        final disclosureLabel = formatMarketSnapshotDiscoverDisclosureLabel(
          expanded: _expanded,
        );
        final summaryLine = formatMarketSnapshotDiscoverSummaryLine(snapshot);
        final disclosureStyle = CollectibleTypography.figureMeta(textTheme, scheme)
            .copyWith(
          color: _kGalleryForeground.withValues(alpha: 0.72),
          fontWeight: FontWeight.w600,
        );
        final summaryStyle = CollectibleTypography.figureMeta(textTheme, scheme)
            .copyWith(
          color: _kGalleryForeground.withValues(alpha: 0.82),
          fontWeight: FontWeight.w500,
        );

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            button: true,
            expanded: _expanded,
            label: kMarketSnapshotDiscoverDisclosureHeading,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              splashColor: _kGalleryForeground.withValues(alpha: 0.08),
              highlightColor: _kGalleryForeground.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    Text(
                      disclosureLabel,
                      textAlign: TextAlign.center,
                      style: disclosureStyle,
                    ),
                    AnimatedSize(
                      duration: CollectibleMotion.crossfade,
                      curve: CollectibleMotion.standard,
                      alignment: Alignment.topCenter,
                      child: _expanded
                          ? Column(
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  summaryLine,
                                  textAlign: TextAlign.center,
                                  style: summaryStyle,
                                ),
                                MarketSnapshotDiscoverExpandPanel(
                                  snapshot: snapshot,
                                  foregroundColor: _kGalleryForeground,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _GalleryDragHandle extends StatefulWidget {
  const _GalleryDragHandle({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_GalleryDragHandle> createState() => _GalleryDragHandleState();
}

class _GalleryDragHandleState extends State<_GalleryDragHandle> {
  double _dragDy = 0;

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dragDy > 56 || v > 220) {
      widget.onDismiss();
    }
    _dragDy = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onVerticalDragStart: (_) => _dragDy = 0,
      onVerticalDragUpdate: (d) {
        if ((d.primaryDelta ?? 0) > 0) {
          _dragDy += d.primaryDelta ?? 0;
        }
      },
      onVerticalDragEnd: _onDragEnd,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Center(
          child: CollectibleSheetDragHandle(
            color: _kGalleryForeground.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _GalleryPageIndicator extends StatelessWidget {
  const _GalleryPageIndicator({
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: CollectibleMotion.crossfade,
            curve: CollectibleMotion.standard,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i == index
                  ? _kGalleryForeground.withValues(alpha: 0.92)
                  : _kGalleryForeground.withValues(alpha: 0.32),
            ),
          ),
      ],
    );
  }
}
