import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as seed_catalog;
import 'package:blindbox_app/features/catalog/search/catalog_search_result.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_catalog.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/add_series_catalog_copy.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
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

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    loadCatalogSeedBundle().then((b) {
      if (mounted) setState(() => _catalogBundle = b);
    }).catchError((_) {
      if (mounted) setState(() => _catalogLoadFailed = true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();

  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

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
      final seriesCover = series.thumbnailAsset.trim();
      final fallbackFig = agg.firstHit.thumbnailAsset.trim();
      final cover = seriesCover.isNotEmpty ? seriesCover : fallbackFig;

      final names = agg.matchedFigureNames.toList()..sort();
      final matchLine =
          names.length == 1 ? 'Includes ${names.first}' : 'Matched: ${names.join(', ')}';

      return _SeriesSearchRow(
        seriesId: sid,
        seriesTitle: series.displayName,
        coverImageRef: cover,
        matchLine: matchLine,
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
    final suggestions = CollectionCatalog.suggestedSeries(snap);
    final catalogActive = _trimmedQuery.isNotEmpty;

    List<CatalogSeries> legacyFiltered(List<CatalogSeries> list) {
      if (_trimmedQuery.isEmpty) return list;
      final q = _trimmedQuery.toLowerCase();
      return list.where((s) {
        final hay = '${s.name} ${s.ipName} ${s.brand}'.toLowerCase();
        return hay.contains(q);
      }).toList(growable: false);
    }

    final filteredSuggestions = legacyFiltered(suggestions);

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
            else if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AddSeriesCatalogCopy.catalogListHeading(searchActive: false),
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
                  : _buildLegacySuggestionsBody(
                      context,
                      scheme,
                      textTheme,
                      suggestions,
                      filteredSuggestions,
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

  Widget _buildLegacySuggestionsBody(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    List<CatalogSeries> suggestions,
    List<CatalogSeries> filtered,
    CollectionNotifier notifier,
  ) {
    if (suggestions.isEmpty) {
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
    if (filtered.isEmpty) {
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
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final s = filtered[i];
        return _SuggestionCard(
          series: s,
          onAdd: () {
            notifier.addSeriesFromTemplate(s);
            Navigator.of(ctx).pop();
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
          'Couldn’t load the local catalog. Try again later.',
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
          onAdd: () {
            final template = catalogTemplateFromSeedSeries(bundle, row.seriesId);
            if (template != null) notifier.addSeriesFromTemplate(template);
            Navigator.of(ctx).pop();
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
    required this.coverImageRef,
    required this.matchLine,
    required this.brandIpLine,
    required this.hasAnySecret,
  });

  final String seriesId;
  final String seriesTitle;
  final String coverImageRef;
  final String matchLine;
  final String brandIpLine;
  final bool hasAnySecret;
}

class _SeriesCatalogSearchRowCard extends StatelessWidget {
  const _SeriesCatalogSearchRowCard({
    required this.row,
    required this.onAdd,
  });

  final _SeriesSearchRow row;
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
        onTap: onAdd,
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
                  child: CollectibleThumbImage(
                    imageRef: row.coverImageRef,
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
                        row.matchLine,
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.series, required this.onAdd});

  final CatalogSeries series;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final previews = series.figures.take(3).toList(growable: false);

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onAdd,
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
                Row(
                  children: [
                    for (var j = 0; j < 3; j++)
                      Padding(
                        padding: EdgeInsets.only(right: j < 2 ? 6 : 0),
                        child: Transform.rotate(
                          angle: (j - 1) * 0.06,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.shadow.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: j < previews.length
                                ? _MiniFigurePreview(figure: previews[j])
                                : ColoredBox(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                  ],
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniFigurePreview extends StatelessWidget {
  const _MiniFigurePreview({required this.figure});

  final CatalogFigure figure;

  @override
  Widget build(BuildContext context) {
    return CollectibleThumbImage(
      imageRef: figure.imageUrl,
      name: figure.name,
      seedKey: figure.templateFigureId,
      isSecret: figure.isSecret,
      compact: true,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(12),
    );
  }
}
