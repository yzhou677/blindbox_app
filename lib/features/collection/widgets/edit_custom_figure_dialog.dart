import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/collection/data/collection_input_formatters.dart';
import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_quiet_field.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_gallery_pick.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

const String editCustomFigureDialogTitle = 'Edit Figure';

/// Edit one custom figure draft — dialog owns controllers (safe cancel).
class EditCustomFigureDialog extends StatefulWidget {
  const EditCustomFigureDialog({
    super.key,
    required this.initial,
    this.dialogTitle = 'Figure',
    this.pickImage,
  });

  final CustomFigureDraft initial;
  final String dialogTitle;

  /// Optional gallery pick override (widget tests).
  final Future<String?> Function(BuildContext context)? pickImage;

  @override
  State<EditCustomFigureDialog> createState() => _EditCustomFigureDialogState();
}

class _EditCustomFigureDialogState extends State<EditCustomFigureDialog> {
  late final TextEditingController _name;
  late final TextEditingController _rarity;
  late bool _isSecret;
  String? _localImageUri;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.displayName);
    _isSecret = widget.initial.isSecret;
    _rarity = TextEditingController(text: widget.initial.rarityLabel ?? '');
    _localImageUri = widget.initial.localImageUri;
  }

  @override
  void dispose() {
    _name.dispose();
    _rarity.dispose();
    super.dispose();
  }

  Future<void> _replaceImage() async {
    final pick = widget.pickImage ?? pickShelfGalleryImage;
    final path = await pick(context);
    if (!mounted || path == null) return;
    setState(() => _localImageUri = path);
  }

  void _removeImage() => setState(() => _localImageUri = null);

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final rarity = _rarity.text.trim();
    Navigator.of(context).pop(
      CustomFigureDraft(
        displayName: name,
        localImageUri: _localImageUri,
        isSecret: _isSecret,
        rarityLabel: _isSecret && rarity.isNotEmpty ? rarity : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = _localImageUri?.trim().isNotEmpty ?? false;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      title: Text(widget.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              maxLength: CollectionInputLimits.figureNameMaxLength,
              inputFormatters: CollectionInputFormatters.figureName(),
              decoration: quietCustomSeriesField(scheme, hintText: 'Name'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Secret',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _isSecret,
              onChanged: (v) => setState(() => _isSecret = v),
            ),
            if (_isSecret) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _rarity,
                textInputAction: TextInputAction.next,
                maxLength: CollectionInputLimits.rarityLabelMaxLength,
                inputFormatters: CollectionInputFormatters.rarityLabel(),
                decoration: quietCustomSeriesField(scheme, hintText: '1:72'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Image',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (hasPhoto) ...[
              ClipRRect(
                borderRadius: AppRadii.insetRadius,
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CollectibleThumbImage(
                    imageRef: _localImageUri,
                    name: _name.text,
                    seedKey: 'fig-dialog-${_name.text}',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: _replaceImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(hasPhoto ? 'Replace' : 'Add photo'),
                ),
                if (hasPhoto) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _removeImage,
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
