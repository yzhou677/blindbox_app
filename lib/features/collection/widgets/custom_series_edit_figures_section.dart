import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/data/collection_input_formatters.dart';
import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_quiet_field.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Figure lineup on custom series edit — tap a row to edit; add new below.
class CustomSeriesEditFiguresSection extends StatelessWidget {
  const CustomSeriesEditFiguresSection({
    super.key,
    required this.figures,
    required this.onFigureTap,
    required this.addFieldController,
    required this.addFieldFocusNode,
    required this.onAddSubmitted,
  });

  final List<ShelfFigure> figures;
  final ValueChanged<ShelfFigure> onFigureTap;
  final TextEditingController addFieldController;
  final FocusNode addFieldFocusNode;
  final VoidCallback onAddSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Figures',
              style: CollectibleTypography.figureMeta(textTheme, scheme).copyWith(
                fontSize: 12,
                letterSpacing: 0.14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (figures.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                '${figures.length}',
                style: CollectibleTypography.figureMeta(textTheme, scheme),
              ),
            ],
          ],
        ),
        if (figures.isNotEmpty) ...[
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: figures.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final figure = figures[i];
              return _ShelfFigureEditRow(
                key: ValueKey('fig-edit-${figure.id}'),
                figure: figure,
                onTap: () => onFigureTap(figure),
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          key: const Key('custom-series-edit-add-figure-field'),
          controller: addFieldController,
          focusNode: addFieldFocusNode,
          textInputAction: TextInputAction.done,
          maxLength: CollectionInputLimits.figureNameMaxLength,
          inputFormatters: CollectionInputFormatters.figureName(),
          onSubmitted: (_) => onAddSubmitted(),
          style: CollectibleTypography.figureCaption(textTheme, scheme),
          decoration: quietCustomSeriesField(
            scheme,
            hintText: 'Figure name',
          ).copyWith(
            suffixIcon: IconButton(
              key: const Key('custom-series-edit-add-figure-button'),
              onPressed: onAddSubmitted,
              tooltip: 'Add figure',
              icon: Icon(
                Icons.add_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              visualDensity: VisualDensity.compact,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfFigureEditRow extends StatelessWidget {
  const _ShelfFigureEditRow({
    super.key,
    required this.figure,
    required this.onTap,
  });

  final ShelfFigure figure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = figure.localImageUri?.trim().isNotEmpty ?? false;
    final secretMeta = _secretMeta(figure);

    return Semantics(
      button: true,
      label: 'Edit ${figure.name}',
      child: Material(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: AppRadii.fieldRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                if (hasPhoto) ...[
                  ClipRRect(
                    borderRadius: AppRadii.insetRadius,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CollectibleThumbImage(
                        imageRef: figure.localImageUri,
                        name: figure.name,
                        seedKey: 'fig-edit-${figure.id}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        figure.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CollectibleTypography.figureCaption(
                          textTheme,
                          scheme,
                        ),
                      ),
                      if (secretMeta != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          secretMeta,
                          style: CollectibleTypography.figureMeta(
                            textTheme,
                            scheme,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _secretMeta(ShelfFigure figure) {
    if (!figure.isSecret) return null;
    final ratio = figure.rarityLabel?.trim();
    if (ratio != null && ratio.isNotEmpty) return 'Secret · $ratio';
    return 'Secret';
  }
}
