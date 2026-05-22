import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_quiet_field.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Figure lineup for custom series — list rows, edit in dialog.
class FigureNameChipsEditor extends StatelessWidget {
  const FigureNameChipsEditor({
    super.key,
    required this.figures,
    required this.onRemoveAt,
    required this.onEditAt,
    required this.addFieldController,
    required this.onAddSubmitted,
    required this.addFieldFocusNode,
    required this.onPickFigurePhoto,
  });

  final List<CustomFigureDraft> figures;
  final ValueChanged<int> onRemoveAt;
  final ValueChanged<int> onEditAt;
  final TextEditingController addFieldController;
  final VoidCallback onAddSubmitted;
  final FocusNode addFieldFocusNode;
  final ValueChanged<int> onPickFigurePhoto;

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
              style: CollectibleTypography.figureMeta(textTheme, scheme)
                  .copyWith(
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
            itemBuilder: (context, i) => _FigureDraftRow(
              key: ValueKey('fig-draft-$i-${figures[i].displayName}'),
              draft: figures[i],
              onTap: () => onEditAt(i),
              onPickPhoto: () => onPickFigurePhoto(i),
              onRemove: () => onRemoveAt(i),
            ),
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 12),
        TextField(
          controller: addFieldController,
          focusNode: addFieldFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAddSubmitted(),
          style: CollectibleTypography.figureCaption(textTheme, scheme),
          decoration: quietCustomSeriesField(
            scheme,
            hintText: 'Figure name',
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: onAddSubmitted,
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

class _FigureDraftRow extends StatelessWidget {
  const _FigureDraftRow({
    super.key,
    required this.draft,
    required this.onTap,
    required this.onPickPhoto,
    required this.onRemove,
  });

  final CustomFigureDraft draft;
  final VoidCallback onTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = draft.localImageUri?.trim().isNotEmpty ?? false;
    final secretMeta = _secretMeta(draft);

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
      borderRadius: AppRadii.fieldRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              if (hasPhoto) ...[
                ClipRRect(
                  borderRadius: AppRadii.insetRadius,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CollectibleThumbImage(
                      imageRef: draft.localImageUri,
                      name: draft.displayName,
                      seedKey: 'fig-draft-${draft.displayName}',
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
                      draft.displayName,
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
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: hasPhoto ? 'Change photo' : 'Photo',
                icon: Icon(
                  hasPhoto
                      ? Icons.image_outlined
                      : Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                onPressed: onPickPhoto,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _secretMeta(CustomFigureDraft draft) {
    if (!draft.isSecret) return null;
    final ratio = draft.rarityLabel?.trim();
    if (ratio != null && ratio.isNotEmpty) return 'Secret · $ratio';
    return 'Secret';
  }
}
