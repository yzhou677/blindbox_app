import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Read-only figure lineup on custom series edit — tap a row to edit metadata.
class CustomSeriesEditFiguresSection extends StatelessWidget {
  const CustomSeriesEditFiguresSection({
    super.key,
    required this.figures,
    required this.onFigureTap,
  });

  final List<ShelfFigure> figures;
  final ValueChanged<ShelfFigure> onFigureTap;

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
        if (figures.isEmpty)
          const SizedBox(height: 4)
        else ...[
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
