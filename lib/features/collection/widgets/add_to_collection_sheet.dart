import 'dart:math' as math;

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_catalog.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Add from catalog suggestions or jump out to create a custom line.
class AddToCollectionSheet extends ConsumerWidget {
  const AddToCollectionSheet({super.key, required this.onCreateCustom});

  final VoidCallback onCreateCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final snap = ref.watch(collectionNotifierProvider);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final suggestions = CollectionCatalog.suggestedSeries(snap);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 16),
          Text(
            'Add to your shelf',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a suggested line or start your own — your shelf stays the source of truth.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: math.min(320, MediaQuery.sizeOf(context).height * 0.42),
            child: suggestions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Every catalog line here is already on your shelf. Nice collection.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: suggestions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final s = suggestions[i];
                      return _SuggestionTile(
                        series: s,
                        onTap: () {
                          notifier.addSeriesFromTemplate(s);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onCreateCustom,
            child: const Text('Create my own line'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.series, required this.onTap});

  final SeriesDefinition series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: series.shelfAccent.withValues(alpha: 0.85),
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
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${series.ipName} · ${series.brand} · ${series.figureCount} figures',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_rounded,
                color: scheme.primary.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
