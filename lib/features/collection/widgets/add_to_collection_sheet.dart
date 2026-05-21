import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle_loader.dart';
import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as seed_catalog;
import 'package:blindbox_app/features/catalog/search/catalog_search_result.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/add_series_catalog_copy.dart';
import 'package:blindbox_app/features/collection/presentation/catalog_search_row_summary.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Add from catalog suggestions (searchable) or create a custom series.
class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.onCreateCustom});

  final VoidCallback onCreateCustom;

  @override
  ConsumerState<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
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
    loadCatalogBundle().then((b) {
      if (!mounted) return;
      final snap = ref.read(collectionNotifierProvider);
      MarketTaxonomy.applyCatalogBundle(b);
      setState(() {
        _catalogBundle = b;
        _catalogLoadFailed = false;
        _recommendationsFuture = _loadRecommendationTemplates(b, snap);
      });
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _catalogLoadFailed = true;
          _catalogBundle = null;
          _recommendationsFuture = null;
        });
      }
    });
  }

  Future<List<CatalogSeries>> _loadRecommendationTemplates(
    CatalogSeedBundle bundle,
    CollectionSnapshot snap,
  ) async {
    final picks = pickLatestSeriesRecommendations(bundle, snap);
    final out = <CatalogSeries>[];
    for (final seedSeries in picks) {
      final template = await catalogTemplateFromSeedSeries(
        bundle,
        seedSeries.id,
        resolveFigureImages: false,
      );
      if (template != null) out.add(template);
    }
    return out;
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

  int _figureCountInSeries(CatalogSeedBundle bundle, String seriesId) {
    var n = 0;
    for (final f in bundle.figures) {
      if (f.seriesId == seriesId) n++;
    }
    return n;
  }

  void _openCatalogSeriesPreview(
    BuildContext context, {
    required CatalogSeries series,
    required VoidCallback onAdd,
  }) {
    final h = MediaQuery.sizeOf(context).height * 0.74;
    showModalBottomSheet<void>(
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
          child: CatalogSeriesPreviewSheet(
            series: series,
            onAdd: onAdd,
          ),
        ),
      ),
    );
  }

  String _brandIpLineForSeries(CatalogSeedBundle bundle, seed_catalog.CatalogSeries series) {
    var brandName = series.brandId;
    for (final b in bundle.brands) {
      if (b.id == series.brandId) {
        brandName = b.displayName;
        break;
      }
    }
    var ipName = series.ipId;
    for (final i in bundle.ips) {
      if (i.id == series.ipId) {
        ipName = i.displayName;
        break;
      }
    }
    return '$brandName · $ipName';
  }

  /// One row per series; order follows [CatalogSearchService] ranking (first hit
  /// per series defines list position and cover / match copy).
  List<_SeriesSearchRow> _seriesSearchRows({
    required CatalogSeedBundle bundle,
    required CollectionSnapshot snap,
    required String query,
  }) {
    final svc = CatalogSearchService(bundle);
    final raw = svc.search(query);
    final figureSeriesId = {for (final f in bundle.figures) f.id: f.seriesId};
    final seriesById = {for (final s in bundle.series) s.id: s};

    final order = <String>[];
    final groups = <String, _SeriesSearchAgg>{};

    for (final r in raw) {
      final sid = figureSeriesId[r.figureId];
      if (sid == null) continue;
      if (snap.hasTemplateOnShelf(sid)) continue;

      final existing = groups[sid];
      if (existing == null) {
        order.add(sid);
        groups[sid] = _SeriesSearchAgg(
          firstHit: r,
          matchedFigureNames: {r.figureName},
          hasAnySecret: r.isSecret,
        );
      } else {
        existing.matchedFigureNames.add(r.figureName);
        existing.hasAnySecret = existing.hasAnySecret || r.isSecret;
      }
    }

    return order.map((sid) {
      final agg = groups[sid]!;
      final series = seriesById[sid];
      if (series == null) {
        throw StateError('Catalog seed missing series $sid');
      }
      final coverKey = series.imageKey.trim();

      final figureCount = _figureCountInSeries(bundle, sid);
      final summaryLine = catalogSearchRowSummary(
        figureCount: figureCount,
        hasChase: agg.hasAnySecret,
        matchedFigureNames: agg.matchedFigureNames,
      );

      return _SeriesSearchRow(
        seriesId: sid,
        seriesTitle: series.displayName,
        coverImageKey: coverKey,
        summaryLine: summaryLine,
        brandIpLine: _brandIpLineForSeries(bundle, series),
        hasAnySecret: agg.hasAnySecret,
      );
    }).toList(growable: false);
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
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search catalog — figures, series, IPs, aliases…',
                prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
                suffixIcon: !_hasSearchText
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.35),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                isDense: true,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            final coverKey = _seriesCoverImageKey(_catalogBundle!, s.templateId);
            return _SuggestionCard(
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

    final matches = _seriesSearchRows(bundle: bundle, snap: snap, query: _trimmedQuery);
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
        return _SeriesCatalogSearchRowCard(
          row: row,
          onOpenPreview: () async {
            final template = await catalogTemplateFromSeedSeries(bundle, row.seriesId);
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
          onAdd: () async {
            final template = await catalogTemplateFromSeedSeries(bundle, row.seriesId);
            if (template != null) await _addCatalogSeriesToShelf(notifier, template);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        );
      },
    );
  }
}

class _SeriesSearchAgg {
  _SeriesSearchAgg({
    required this.firstHit,
    required this.matchedFigureNames,
    required this.hasAnySecret,
  });

  final CatalogSearchResult firstHit;
  final Set<String> matchedFigureNames;
  bool hasAnySecret;
}

class _SeriesSearchRow {
  const _SeriesSearchRow({
    required this.seriesId,
    required this.seriesTitle,
    required this.coverImageKey,
    required this.summaryLine,
    required this.brandIpLine,
    required this.hasAnySecret,
  });

  final String seriesId;
  final String seriesTitle;
  final String coverImageKey;
  final String summaryLine;
  final String brandIpLine;
  final bool hasAnySecret;
}

class _SeriesCatalogSearchRowCard extends StatelessWidget {
  const _SeriesCatalogSearchRowCard({
    required this.row,
    required this.onOpenPreview,
    required this.onAdd,
  });

  final _SeriesSearchRow row;
  final VoidCallback onOpenPreview;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secretTint = scheme.tertiary;

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
              color: row.hasAnySecret
                  ? secretTint.withValues(alpha: 0.38)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            color: row.hasAnySecret
                ? Color.lerp(scheme.surfaceContainerLow, secretTint, 0.07)
                : scheme.surfaceContainerLow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CatalogImageFromKey(
                    imageKey: row.coverImageKey,
                    series: true,
                    name: row.seriesTitle,
                    seedKey: row.seriesId,
                    isSecret: row.hasAnySecret,
                    compact: true,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.seriesTitle,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.14,
                              ),
                            ),
                          ),
                          if (row.hasAnySecret)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: secretTint.withValues(alpha: 0.88),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.summaryLine,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.brandIpLine,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          Icon(Icons.add_rounded, size: 20, color: scheme.primary),
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
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
            border: Border.all(color: series.shelfAccent.withValues(alpha: 0.42)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerLow,
                Color.lerp(scheme.surfaceContainerLow, series.shelfAccent, 0.12)!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: coverImageKey.isNotEmpty
                      ? CatalogImageFromKey(
                          imageKey: coverImageKey,
                          series: true,
                          name: series.name,
                          seedKey: series.templateId,
                          compact: true,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(14),
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          child: Icon(
                            Icons.auto_awesome_motion_rounded,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
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
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${series.brand} · ${series.figureCount} figures',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          Icon(Icons.add_rounded, size: 20, color: scheme.primary),
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

