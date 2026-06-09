import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/collection/data/collection_input_formatters.dart';
import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_quiet_field.dart';
import 'package:flutter/material.dart';

/// Edit one custom figure draft — dialog owns controllers (safe cancel).
class EditCustomFigureDialog extends StatefulWidget {
  const EditCustomFigureDialog({super.key, required this.initial});

  final CustomFigureDraft initial;

  @override
  State<EditCustomFigureDialog> createState() => _EditCustomFigureDialogState();
}

class _EditCustomFigureDialogState extends State<EditCustomFigureDialog> {
  late final TextEditingController _name;
  late final TextEditingController _rarity;
  late bool _isSecret;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.displayName);
    _isSecret = widget.initial.isSecret;
    _rarity = TextEditingController(text: widget.initial.rarityLabel ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _rarity.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final rarity = _rarity.text.trim();
    Navigator.of(context).pop(
      CustomFigureDraft(
        displayName: name,
        localImageUri: widget.initial.localImageUri,
        isSecret: _isSecret,
        rarityLabel: _isSecret && rarity.isNotEmpty ? rarity : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      title: const Text('Figure'),
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
                textInputAction: TextInputAction.done,
                maxLength: CollectionInputLimits.rarityLabelMaxLength,
                inputFormatters: CollectionInputFormatters.rarityLabel(),
                onSubmitted: (_) => _save(),
                decoration: quietCustomSeriesField(scheme, hintText: '1:72'),
              ),
            ],
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
