import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_art.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contextual management for a shelf series — long-press confirmation sheet.
///
/// Editorial confirmation surface (not a dense menu):
/// identity → optional Edit → destructive Remove → isolated Cancel.
Future<void> showCollectionSeriesManagementActions({
  required BuildContext context,
  required WidgetRef ref,
  required ShelfSeries series,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: scheme.surface,
    barrierColor: CollectibleImmersion.sheetBarrier(scheme),
    sheetAnimationStyle: CollectibleMotion.sheetAnimationStyle(),
    shape: AppRadii.sheetShape,
    builder: (ctx) => _CollectionSeriesManagementSheet(
      series: series,
      onEdit: series.isCustomLocal
          ? () {
              Navigator.pop(ctx);
              openEditCustomSeriesSheet(context, ref, series);
            }
          : null,
      onRemove: () {
        Navigator.pop(ctx);
        confirmAndRemoveSeries(
          context: context,
          ref: ref,
          seriesId: series.id,
          seriesName: series.name,
        );
      },
      onCancel: () => Navigator.pop(ctx),
    ),
  );
}

bool _seriesHasCover(ShelfSeries series) {
  final userCover = ShelfFigureMedia.seriesCoverRef(series)?.trim();
  if (userCover != null && userCover.isNotEmpty) return true;
  final catalogKey = CollectionSeriesArt.catalogSeriesImageKey(series);
  return catalogKey != null && catalogKey.isNotEmpty;
}

String? _seriesSubtitle(ShelfSeries series) {
  final ip = shelfSeriesIpLabel(series).trim();
  if (ip.isNotEmpty) return ip;
  final brand = series.brand.trim();
  if (brand.isNotEmpty) return brand;
  return series.isCustomLocal ? 'Your series' : null;
}

/// Premium confirmation sheet — calm hierarchy, not a ListTile menu.
class _CollectionSeriesManagementSheet extends StatelessWidget {
  const _CollectionSeriesManagementSheet({
    required this.series,
    required this.onRemove,
    required this.onCancel,
    this.onEdit,
  });

  final ShelfSeries series;
  final VoidCallback? onEdit;
  final VoidCallback onRemove;
  final VoidCallback onCancel;

  static const _coverExtent = 96.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showCover = _seriesHasCover(series);
    final subtitle = _seriesSubtitle(series);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: showCover ? AppSpacing.xl : AppSpacing.lg + 4),
            if (showCover) ...[
              Center(
                child: CollectionSeriesThumbnail(
                  series: series,
                  extent: _coverExtent,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              series.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CollectibleTypography.seriesHeroTitle(
                textTheme,
                scheme,
              ).copyWith(
                fontSize: 22,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CollectibleTypography.seriesIpLine(textTheme, scheme),
              ),
            ],
            const SizedBox(height: AppSpacing.xl + 4),
            if (onEdit != null) ...[
              _ManagementActionButton(
                label: CollectionVocabulary.editSeries,
                onPressed: onEdit!,
                foreground: scheme.onSurface.withValues(alpha: 0.88),
                background: scheme.surfaceContainerHighest.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.45
                      : 0.55,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Destructive section — visually separated.
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.28
                      : 0.42,
                ),
                borderRadius: AppRadii.fieldRadius,
              ),
              child: _ManagementActionButton(
                label: CollectionVocabulary.removeFromCollection,
                onPressed: onRemove,
                foreground: scheme.error,
                background: Colors.transparent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Cancel isolated at the bottom (iOS confirmation convention).
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                CollectionVocabulary.cancel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementActionButton extends StatelessWidget {
  const _ManagementActionButton({
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.background,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: AppRadii.fieldRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.fieldRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: fontWeight,
                  letterSpacing: 0.05,
                  height: 1.25,
                ),
          ),
        ),
      ),
    );
  }
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
