import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Opens the Collection Layout sheet (layout + Card Content). Prefs apply live.
Future<void> showCollectionShelfLayoutSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<ShelfSeries> shelfSeries,
  required Map<String, TrackedFigure> figureStates,
  CatalogSeedBundle? catalog,
  ShelfBrowseProgressLookup? progress,
}) {
  final available = availableCollectionShelfCardContentFields(
    shelfSeries: shelfSeries,
    figureStates: figureStates,
    catalog: catalog,
    progress: progress,
  );

  return showCollectionModalBottomSheet<void>(
    context: context,
    // Layout rows + Card Content section.
    heightFraction: 0.72,
    builder: (context, scrollController) {
      return Consumer(
        builder: (context, sheetRef, _) {
          final prefs = sheetRef.watch(collectionShelfUiPrefsProvider);
          final selectedLayout = prefs.layout;
          final selection = prefs.cardContentSelection
              .sanitizePreservingUnavailable(available);
          return CollectionShelfLayoutSheet(
            scrollController: scrollController,
            selectedLayout: selectedLayout,
            selection: selection,
            available: available,
            onLayoutSelected: (layout) {
              sheetRef
                  .read(collectionShelfUiPrefsProvider.notifier)
                  .setLayout(layout);
            },
            onToggleCardContent: (field) {
              sheetRef
                  .read(collectionShelfUiPrefsProvider.notifier)
                  .toggleCardContentField(field, available: available);
            },
          );
        },
      );
    },
  );
}

class CollectionShelfLayoutSheet extends StatelessWidget {
  const CollectionShelfLayoutSheet({
    super.key,
    required this.scrollController,
    required this.selectedLayout,
    required this.selection,
    required this.available,
    required this.onLayoutSelected,
    required this.onToggleCardContent,
  });

  final ScrollController scrollController;
  final CollectionShelfLayout selectedLayout;
  final CollectionShelfCardContentSelection selection;
  final Set<CollectionShelfCardContentField> available;
  final ValueChanged<CollectionShelfLayout> onLayoutSelected;
  final ValueChanged<CollectionShelfCardContentField> onToggleCardContent;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selection.availableSelectedCount(available);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CollectibleSheetInsets(
      extraBottom: 0,
      child: CollectibleSheetScrollView(
        controller: scrollController,
        header: const CollectibleSheetChrome(
          editorialTitle: CollectionVocabulary.layoutMenuTitle,
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.sheetTitleToBody,
                bottom: FeedRhythm.sheetBodyBottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final layout in CollectionShelfLayout.values)
                    _LayoutOptionRow(
                      layout: layout,
                      selected: layout == selectedLayout,
                      scheme: scheme,
                      textTheme: textTheme,
                      onTap: () => onLayoutSelected(layout),
                    ),
                  if (available.isNotEmpty) ...[
                    const SizedBox(height: FeedRhythm.sheetSectionGap),
                    Text(
                      CollectionVocabulary.cardContentSectionTitle,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: FeedRhythm.sheetLabelToControl / 2),
                    Text(
                      CollectionVocabulary.cardContentSectionSubtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: FeedRhythm.sheetLabelToControl),
                    for (final field in CollectionShelfCardContentField.values)
                      if (available.contains(field))
                        _CardContentOptionRow(
                          field: field,
                          selected: selection.contains(field),
                          enabled:
                              selection.contains(field) ||
                              selectedCount <
                                  kMaxCollectionShelfCardContentSelections,
                          scheme: scheme,
                          textTheme: textTheme,
                          onTap: () => onToggleCardContent(field),
                        ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      CollectionVocabulary.cardContentSelectionCount(
                        selectedCount,
                        kMaxCollectionShelfCardContentSelections,
                      ),
                      key: const Key('card_content_selection_count'),
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutOptionRow extends StatelessWidget {
  const _LayoutOptionRow({
    required this.layout,
    required this.selected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final CollectionShelfLayout layout;
  final bool selected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  static const double _rowMinHeight = 52;
  static const double _iconLabelGap = AppSpacing.md; // 12

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('collection_layout_option_${layout.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  layout.icon,
                  size: AppIconSizes.toolbar,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: _iconLabelGap),
                Expanded(
                  child: Text(
                    layout.menuLabel,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Symbols.radio_button_checked_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContentOptionRow extends StatelessWidget {
  const _CardContentOptionRow({
    required this.field,
    required this.selected,
    required this.enabled,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final CollectionShelfCardContentField field;
  final bool selected;
  final bool enabled;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  static const double _rowMinHeight = 48;

  @override
  Widget build(BuildContext context) {
    final dimmed = !enabled && !selected;
    final iconColor = selected
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: dimmed ? 0.42 : 0.88);
    final labelColor = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: dimmed ? 0.45 : 1);

    return Semantics(
      checked: selected,
      enabled: enabled || selected,
      label: field.sheetLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('card_content_option_${field.id}'),
          onTap: (enabled || selected) ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    field.sheetIcon,
                    size: AppIconSizes.metadata,
                    color: iconColor,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      field.sheetLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Checkbox(
                      value: selected,
                      onChanged: (enabled || selected) ? (_) {} : null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact toolbar control showing the active layout icon.
class CollectionShelfLayoutControl extends StatelessWidget {
  const CollectionShelfLayoutControl({
    super.key,
    required this.layout,
    required this.onPressed,
  });

  final CollectionShelfLayout layout;
  final VoidCallback onPressed;

  /// Accessible minimum hit target (Material guidance).
  static const double minTapExtent = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: layout.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collection_shelf_layout_control'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: minTapExtent,
            height: minTapExtent,
            // Glyph centered in the 48×48 target; spacing to Sort is owned by
            // the toolbar Row (AppSpacing.sm), not icon edge-alignment.
            child: Align(
              alignment: Alignment.center,
              child: Icon(
                layout.icon,
                size: AppIconSizes.metadata,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtered-empty shelf message with clear-filters action.
class CollectionShelfFilteredEmptyState extends StatelessWidget {
  const CollectionShelfFilteredEmptyState({
    super.key,
    required this.onClearFilters,
    this.message = CollectionVocabulary.filteredEmptyTitle,
  });

  final VoidCallback onClearFilters;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
          const SizedBox(height: FeedRhythm.sheetLabelToControl),
          TextButton(
            key: const Key('collection_clear_filters_cta'),
            onPressed: onClearFilters,
            child: Text(
              CollectionVocabulary.filteredEmptyAction,
              style: CollectibleTypography.shelfFigureSheetSectionLabel(
                textTheme,
                scheme,
              ).copyWith(color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
