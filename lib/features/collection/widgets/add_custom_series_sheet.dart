import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_cover_slot.dart';
import 'package:blindbox_app/features/collection/widgets/edit_custom_figure_dialog.dart';
import 'package:blindbox_app/features/collection/widgets/figure_name_chips_editor.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_gallery_pick.dart';
import 'package:flutter/material.dart';

typedef CustomSeriesFormSubmit = void Function({
  required String seriesName,
  String? brand,
  String? ipDisplayName,
  required List<CustomFigureDraft> figures,
  String? customCoverImageUri,
  String? notes,
});

/// Shelf-first custom series — chips for figures, light fields for the rest.
class AddCustomSeriesSheet extends StatefulWidget {
  const AddCustomSeriesSheet({super.key, required this.onSubmit});

  final CustomSeriesFormSubmit onSubmit;

  @override
  State<AddCustomSeriesSheet> createState() => _AddCustomSeriesSheetState();
}

class _AddCustomSeriesSheetState extends State<AddCustomSeriesSheet> {
  final _seriesName = TextEditingController();
  final _brand = TextEditingController();
  final _ip = TextEditingController();
  final _notes = TextEditingController();
  final _newFigure = TextEditingController();
  final _newFigureFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  final List<CustomFigureDraft> _figures = [];
  String? _coverUri;

  @override
  void dispose() {
    _seriesName.dispose();
    _brand.dispose();
    _ip.dispose();
    _notes.dispose();
    _newFigure.dispose();
    _newFigureFocus.dispose();
    super.dispose();
  }

  void _addFigureFromField() {
    final raw = _newFigure.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _figures.add(CustomFigureDraft(displayName: raw));
      _newFigure.clear();
    });
  }

  Future<void> _editAt(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current = _figures[index];
    final next = await showDialog<CustomFigureDraft>(
      context: context,
      builder: (ctx) => EditCustomFigureDialog(initial: current),
    );
    if (!mounted || next == null) return;
    setState(() => _figures[index] = next);
  }

  void _removeAt(int i) {
    setState(() => _figures.removeAt(i));
  }

  void _setSecret(int i, bool isSecret) {
    setState(() {
      final f = _figures[i];
      _figures[i] = CustomFigureDraft(
        displayName: f.displayName,
        localImageUri: f.localImageUri,
        isSecret: isSecret,
        rarityLabel: isSecret ? f.rarityLabel : null,
      );
    });
  }

  void _setRarityLabel(int i, String? label) {
    final trimmed = label?.trim();
    setState(() {
      final f = _figures[i];
      _figures[i] = CustomFigureDraft(
        displayName: f.displayName,
        localImageUri: f.localImageUri,
        isSecret: f.isSecret,
        rarityLabel: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      );
    });
  }

  Future<void> _pickCover() async {
    final path = await pickShelfGalleryImage(context);
    if (!mounted || path == null) return;
    setState(() => _coverUri = path);
  }

  void _clearCover() => setState(() => _coverUri = null);

  Future<void> _pickFigurePhoto(int i) async {
    final path = await pickShelfGalleryImage(context);
    if (!mounted || path == null) return;
    setState(() {
      final f = _figures[i];
      _figures[i] = CustomFigureDraft(
        displayName: f.displayName,
        localImageUri: path,
        isSecret: f.isSecret,
        rarityLabel: f.rarityLabel,
      );
    });
  }

  void _clearFigurePhoto(int i) {
    setState(() {
      final f = _figures[i];
      _figures[i] = CustomFigureDraft(
        displayName: f.displayName,
        isSecret: f.isSecret,
        rarityLabel: f.rarityLabel,
      );
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_figures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one figure')),
      );
      return;
    }
    widget.onSubmit(
      seriesName: _seriesName.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      ipDisplayName: _ip.text.trim().isEmpty ? null : _ip.text.trim(),
      figures: List<CustomFigureDraft>.from(_figures),
      customCoverImageUri: _coverUri,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: maxH,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your own series',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Give the series a name, tag your pulls, and they’ll land on your shelf like the rest.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      CustomSeriesCoverSlot(
                        imagePath: _coverUri,
                        onReplaceTap: _pickCover,
                        onClearTap: _clearCover,
                      ),
                      const SizedBox(height: 22),
                      Text.rich(
                        TextSpan(
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.9),
                          ),
                          children: [
                            const TextSpan(text: 'Series name '),
                            TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: scheme.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _seriesName,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'e.g. The Other One',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Add a series name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _brand,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Brand (optional)',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ip,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'IP / universe (optional)',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FigureNameChipsEditor(
                        figures: _figures,
                        onRemoveAt: _removeAt,
                        onEditAt: _editAt,
                        addFieldController: _newFigure,
                        addFieldFocusNode: _newFigureFocus,
                        onAddSubmitted: _addFigureFromField,
                        onPickFigurePhoto: _pickFigurePhoto,
                        onClearFigurePhoto: _clearFigurePhoto,
                        onSecretChanged: _setSecret,
                        onRarityLabelChanged: _setRarityLabel,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _notes,
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Shelf note',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Place on shelf'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
