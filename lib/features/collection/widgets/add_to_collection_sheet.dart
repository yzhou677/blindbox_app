import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_catalog.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SeriesDefinition> _filtered(List<SeriesDefinition> suggestions) {
    if (_query.isEmpty) return suggestions;
    return suggestions.where((s) {
      final hay = '${s.name} ${s.ipName} ${s.brand}'.toLowerCase();
      return hay.contains(_query);
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
    final filtered = _filtered(suggestions);

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
              'Search suggestions from the catalog — they’re just shortcuts; your shelf stays yours.',
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
                hintText: 'Search by series, IP, or brand…',
                prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
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
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Suggestions',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${filtered.length}/${suggestions.length}',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: suggestions.isEmpty
                  ? Center(
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
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matches — try another word.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        )
                      : ListView.separated(
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
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.series, required this.onAdd});

  final SeriesDefinition series;
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

  final FigureDefinition figure;

  @override
  Widget build(BuildContext context) {
    if (figure.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: figure.imageUrl!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        errorWidget: (context, url, error) => CollectibleFigurePlaceholder(
          name: figure.name,
          seedKey: figure.id,
          isSecret: figure.isSecret,
          compact: true,
        ),
      );
    }
    return CollectibleFigurePlaceholder(
      name: figure.name,
      seedKey: figure.id,
      isSecret: figure.isSecret,
      compact: true,
    );
  }
}
