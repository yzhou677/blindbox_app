import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_page.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_precache.dart';
import 'package:flutter/material.dart';

/// Opens an immersive fullscreen figure gallery (swipe between figures, drag to dismiss).
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
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return CatalogFigureGallerySheet(
          items: items,
          initialIndex: index,
          seriesTitle: seriesTitle,
          routeAnimation: animation,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.items[_currentIndex];
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
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: ColoredBox(
                  color: scheme.scrim.withValues(alpha: 0.5),
                ),
              ),
            ),
            SafeArea(
              child: Column(
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
                          icon: Icon(
                            Icons.close_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.92),
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
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.72,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              Text(
                                '${_currentIndex + 1} of ${widget.items.length}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.55,
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
                        return CatalogFigureGalleryPage(
                          key: ValueKey<String>(
                            'gallery-page:${widget.items[index].id}',
                          ),
                          item: widget.items[index],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Column(
                        key: ValueKey<String>(item.id),
                        children: [
                          Text(
                            item.isSecret ? 'Secret' : item.name,
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: scheme.onSurface.withValues(alpha: 0.96),
                            ),
                          ),
                          if (item.rarityLabel != null &&
                              item.rarityLabel!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.rarityLabel!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _GalleryDragHandle extends StatelessWidget {
  const _GalleryDragHandle({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 380) onDismiss();
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i == index
                  ? scheme.primary.withValues(alpha: 0.85)
                  : scheme.onSurface.withValues(alpha: 0.22),
            ),
          ),
      ],
    );
  }
}
