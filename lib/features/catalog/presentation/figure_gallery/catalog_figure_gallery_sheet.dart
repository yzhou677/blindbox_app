import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_page.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_precache.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final item = widget.items[_currentIndex];
    final metaLine = _figureMetaLine(item);
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
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
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
                              child: Column(
                                children: [
                                  if (widget.seriesTitle != null &&
                                      widget.seriesTitle!.isNotEmpty)
                                    Text(
                                      widget.seriesTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: textTheme.labelLarge?.copyWith(
                                        color: _kGalleryForeground.withValues(
                                          alpha: 0.92,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  Text(
                                    '${_currentIndex + 1} of ${widget.items.length}',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: _kGalleryForeground.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      if (widget.items.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
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
                              if (metaLine != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  metaLine,
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
