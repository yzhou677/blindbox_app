import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contextual management for a shelf series — long-press action sheet entry.
///
/// Catalog-backed: Remove + Cancel.
/// User-created ([ShelfSeries.isCustomLocal]): Edit + Remove + Cancel.
Future<void> showCollectionSeriesManagementActions({
  required BuildContext context,
  required WidgetRef ref,
  required ShelfSeries series,
}) {
  final isCupertino = Theme.of(context).platform == TargetPlatform.iOS ||
      Theme.of(context).platform == TargetPlatform.macOS;

  if (isCupertino) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(series.name),
        actions: [
          if (series.isCustomLocal)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                openEditCustomSeriesSheet(context, ref, series);
              },
              child: const Text(CollectionVocabulary.editSeries),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              confirmAndRemoveSeries(
                context: context,
                ref: ref,
                seriesId: series.id,
                seriesName: series.name,
              );
            },
            child: const Text(CollectionVocabulary.removeFromCollection),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text(CollectionVocabulary.cancel),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                series.name,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (series.isCustomLocal)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text(CollectionVocabulary.editSeries),
                onTap: () {
                  Navigator.pop(ctx);
                  openEditCustomSeriesSheet(context, ref, series);
                },
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: scheme.error,
              ),
              title: Text(
                CollectionVocabulary.removeFromCollection,
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                confirmAndRemoveSeries(
                  context: context,
                  ref: ref,
                  seriesId: series.id,
                  seriesName: series.name,
                );
              },
            ),
            ListTile(
              title: const Text(
                CollectionVocabulary.cancel,
                textAlign: TextAlign.center,
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Opens the custom-series editor sheet (user-created series only).
void openEditCustomSeriesSheet(
  BuildContext context,
  WidgetRef ref,
  ShelfSeries series,
) {
  if (!series.isCustomLocal) return;
  showCollectionModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_, scroll) => CustomSeriesFormSheet.edit(
      initialSeries: series,
      onSubmit:
          ({
            required String seriesName,
            String? brand,
            String? ipDisplayName,
            String? customCoverImageUri,
            String? notes,
          }) {
            ref.read(collectionNotifierProvider.notifier).updateCustomSeries(
                  seriesId: series.id,
                  seriesName: seriesName,
                  brand: brand,
                  ipDisplayName: ipDisplayName,
                  customCoverImageUri: customCoverImageUri,
                  notes: notes,
                );
          },
      onFigureSubmit:
          ({
            required String figureId,
            required String name,
            required bool isSecret,
            String? rarityLabel,
            String? localImageUri,
          }) {
            ref.read(collectionNotifierProvider.notifier).updateCustomFigure(
                  seriesId: series.id,
                  figureId: figureId,
                  name: name,
                  isSecret: isSecret,
                  rarityLabel: rarityLabel,
                  localImageUri: localImageUri,
                );
          },
      onFigureAdd:
          ({
            required String name,
            required bool isSecret,
            String? rarityLabel,
            String? localImageUri,
          }) {
            ref.read(collectionNotifierProvider.notifier).addCustomFigure(
                  seriesId: series.id,
                  name: name,
                  isSecret: isSecret,
                  rarityLabel: rarityLabel,
                  localImageUri: localImageUri,
                );
          },
    ),
  );
}

/// Confirms and removes a series from the shelf (no figures-sheet pop).
Future<void> confirmAndRemoveSeries({
  required BuildContext context,
  required WidgetRef ref,
  required String seriesId,
  required String seriesName,
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Remove series?'),
        content: Text('“$seriesName” will leave your shelf.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(CollectionVocabulary.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(CollectionVocabulary.removeFromCollection),
          ),
        ],
      );
    },
  );
  if (go == true && context.mounted) {
    ref.read(collectionNotifierProvider.notifier).removeSeries(seriesId);
  }
}
