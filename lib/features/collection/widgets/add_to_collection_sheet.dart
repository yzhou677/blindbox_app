import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle_loader.dart';
import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/add_series_catalog_copy.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Add from catalog suggestions (searchable) or create a custom series.
class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.onCreateCustom});

  final VoidCallback onCreateCustom;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  final _search = TextEditingController();
  CatalogSeedBundle? _catalogBundle;
  bool _catalogLoadFailed = false;
  Future<List<CatalogSeries>>? _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadCatalog();
  }

  void _loadCatalog() {
    final cached = CatalogBundleCache.current;
    if (cached != null) {
      _applyCatalogBundle(cached);
    }
    loadCatalogBundle()
        .then((b) {
          if (!mounted) return;
          _applyCatalogBundle(b);
        })
        .catchError((_) {
          if (mounted && _catalogBundle == null) {
            setState(() {
              _catalogLoadFailed = true;
              _catalogBundle = null;
              _recommendationsFuture = null;
            });
          }
        });
  }

  void _applyCatalogBundle(CatalogSeedBundle b) {
    final snap = ref.read(collectionNotifierProvider);
    MarketTaxonomy.applyCatalogBundle(b);
    setState(() {
      _catalogBundle = b;
      _catalogLoadFailed = false;
      _recommendationsFuture = _loadRecommendationTemplates(b, snap);
    });
  }

  Future<List<CatalogSeries>> _loadRecommendationTemplates(
    CatalogSeedBundle bundle,
    CollectionSnapshot snap,
  ) async {
    final picks = pickLatestSeriesRecommendations(bundle, snap);
    final templates = await Future.wait(
      picks.map(
        (seedSeries) => catalogTemplateFromSeedSeries(
          bundle,
          seedSeries.id,
          resolveFigureImages: false,
        ),
      ),
    );
    return [
      for (final t in templates)
        if (t != null) t,
    ];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();

  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  /// Commits a catalog template to the shelf, resolving Storage URLs when the template has no art yet.
  Future<void> _addCatalogSeriesToShelf(
    CollectionNotifier notifier,
    CatalogSeries template,
  ) async {
    var toAdd = template;
    final needsResolve = template.figures.any((f) {
      final u = f.imageUrl?.trim();
      return u == null || u.isEmpty;
    });
    if (needsResolve) {
      final bundle = _catalogBundle;
      if (bundle != null) {
        final resolved = await catalogTemplateFromSeedSeries(
          bundle,
          template.templateId,
          resolveFigureImages: true,
        );
        if (resolved != null) toAdd = resolved;
      }
    }
    notifier.addSeriesFromTemplate(toAdd);
  }

  String _seriesCoverImageKey(CatalogSeedBundle bundle, String seriesId) {
    for (final s in bundle.series) {
      if (s.id == seriesId) return s.imageKey.trim();
    }
    return '';
  }

  void _openCatalogSeriesPreview(
    BuildContext context, {
    required CatalogSeries series,
    required VoidCallback onAdd,
  }) {
    final h = MediaQuery.sizeOf(context).height * 0.74;
    showCollectionModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: h,
          child: CatalogSeriesPreviewSheet(series: series, onAdd: onAdd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final snap = ref.watch(collectionNotifierProvider);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final catalogActive = _trimmedQuery.isNotEmpty;

    final sheetH = MediaQuery.sizeOf(context).height * 0.78;

    return SizedBox(
      height: sheetH,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: bottom + 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add a series',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AddSeriesCatalogCopy.sheetSubtitle,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                height: 1.38,
              ),
            ),
            const SizedBox(height: 16),
            AppSearchField(
              controller: _search,
              padding: EdgeInsets.zero,
              hintText: 'Search catalog — figures, series, IPs, aliases…',
              onChanged: (_) => setState(() {}),
              suffixIcon: !_hasSearchText
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(
                        Icons.close_rounded,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
            const SizedBox(height: 14),
            if (catalogActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Matching series',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
                ),
              )
            else if (!_catalogLoadFailed && _catalogBundle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Latest releases',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
                ),
              ),
            Expanded(
              child: catalogActive
                  ? _buildCatalogSearchBody(
                      context,
                      scheme,
                      textTheme,
                      snap,
                      notifier,
                    )
                  : _buildRecommendationsBody(
                      context,
                      scheme,
                      textTheme,
                      notifier,
                    ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: widget.onCreateCustom,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.draw_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Create my own series'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsBody(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    CollectionNotifier notifier,
  ) {
    if (_catalogLoadFailed) {
      return Center(
        child: Text(
          'Couldn’t load the catalog. Check your connection and try again.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
      );
    }
    if (_catalogBundle == null || _recommendationsFuture == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return FutureBuilder<List<CatalogSeries>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Couldn’t load recommendations.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
          );
        }
        final recs = snapshot.data ?? const <CatalogSeries>[];
        if (recs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Every catalog series here is already on your shelf. Nice.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: recs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final s = recs[i];
            final coverKey = _seriesCoverImageKey(
              _catalogBundle!,
              s.templateId,
            );
            return _SuggestionCard(
              key: ValueKey<String>('add-series-rec:${s.templateId}'),
              series: s,
              coverImageKey: coverKey,
              onOpenPreview: () {
                _openCatalogSeriesPreview(
                  ctx,
                  series: s,
                  onAdd: () async {
                    await _addCatalogSeriesToShelf(notifier, s);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                );
              },
              onAdd: () async {
                await _addCatalogSeriesToShelf(notifier, s);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCatalogSearchBody(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    CollectionSnapshot snap,
    CollectionNotifier notifier,
  ) {
    if (_catalogLoadFailed) {
      return Center(
        child: Text(
          'Couldn’t load the catalog. Check your connection and try again.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
      );
    }
    final bundle = _catalogBundle;
    if (bundle == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final matches = buildCatalogSeriesSearchRows(
      bundle: bundle,
      query: _trimmedQuery,
      excludeSeriesId: snap.hasTemplateOnShelf,
    );
    if (matches.isEmpty) {
      return Center(
        child: Text(
          AddSeriesCatalogCopy.noSearchMatches,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: matches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final row = matches[i];
        return CatalogSeriesSearchRowCard(
          key: ValueKey<String>('add-series-search:${row.seriesId}'),
          row: row,
          trailingLabel: 'Add',
          onOpenPreview: () async {
            final template = await catalogTemplateFromSeedSeries(
              bundle,
              row.seriesId,
            );
            if (!ctx.mounted || template == null) return;
            _openCatalogSeriesPreview(
              ctx,
              series: template,
              onAdd: () async {
                await _addCatalogSeriesToShelf(notifier, template);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            );
          },
          onTrailingAction: () async {
            final template = await catalogTemplateFromSeedSeries(
              bundle,
              row.seriesId,
            );
            if (template != null) {
              await _addCatalogSeriesToShelf(notifier, template);
            }
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        );
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.series,
    required this.coverImageKey,
    required this.onOpenPreview,
    required this.onAdd,
  });

  final CatalogSeries series;
  final String coverImageKey;
  final VoidCallback onOpenPreview;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpenPreview,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: series.shelfAccent.withValues(alpha: 0.42),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerLow,
                Color.lerp(
                  scheme.surfaceContainerLow,
                  series.shelfAccent,
                  0.12,
                )!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CatalogImageSlot(
                  displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                  borderRadius: BorderRadius.circular(14),
                  child: coverImageKey.isNotEmpty
                      ? CatalogImageFromKey(
                          key: catalogImageWidgetKey(
                            displayMode:
                                CatalogImageDisplayMode.seriesCoverThumb,
                            imageKey: coverImageKey,
                            identity: series.templateId,
                          ),
                          imageKey: coverImageKey,
                          name: series.name,
                          seedKey: series.templateId,
                          compact: true,
                          displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                          borderRadius: BorderRadius.zero,
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          child: Icon(
                            Icons.auto_awesome_motion_rounded,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        series.ipName,
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.78,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${series.brand} · ${series.figureCount} figures',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.68,
                          ),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Add',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
