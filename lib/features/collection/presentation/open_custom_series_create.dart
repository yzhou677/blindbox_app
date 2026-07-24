import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the existing custom-series create sheet (shared entry for scan polish).
Future<void> openCustomSeriesCreateSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showCollectionModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_, scroll) => CustomSeriesFormSheet.create(
      onSubmit:
          ({
            required String seriesName,
            String? brand,
            String? ipDisplayName,
            required List<CustomFigureDraft> figures,
            String? customCoverImageUri,
            String? notes,
          }) {
            ref
                .read(collectionNotifierProvider.notifier)
                .addCustomSeries(
                  seriesName: seriesName,
                  brand: brand,
                  ipDisplayName: ipDisplayName,
                  figures: figures,
                  customCoverImageUri: customCoverImageUri,
                  notes: notes,
                );
          },
    ),
  );
}
