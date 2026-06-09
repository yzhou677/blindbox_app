import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_cover_slot.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_quiet_field.dart';
import 'package:blindbox_app/features/collection/widgets/edit_custom_figure_dialog.dart';
import 'package:blindbox_app/features/collection/widgets/figure_name_chips_editor.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_gallery_pick.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';

typedef CustomSeriesFormSubmit =
    void Function({
      required String seriesName,
      String? brand,
      String? ipDisplayName,
      required List<CustomFigureDraft> figures,
      String? customCoverImageUri,
      String? notes,
    });

typedef CustomSeriesMetadataSubmit = void Function({
  required String seriesName,
  String? brand,
  String? ipDisplayName,
  String? customCoverImageUri,
  String? notes,
});

enum CustomSeriesFormMode { create, edit }

/// Shared create/edit form for custom series metadata (figures only on create).
class CustomSeriesFormSheet extends StatefulWidget {
  const CustomSeriesFormSheet.create({
    super.key,
    required CustomSeriesFormSubmit onSubmit,
  })  : mode = CustomSeriesFormMode.create,
        initialSeries = null,
        onCreateSubmit = onSubmit,
        onEditSubmit = null;

  const CustomSeriesFormSheet.edit({
    super.key,
    required ShelfSeries initialSeries,
    required CustomSeriesMetadataSubmit onSubmit,
  })  : mode = CustomSeriesFormMode.edit,
        initialSeries = initialSeries,
        onCreateSubmit = null,
        onEditSubmit = onSubmit;

  final CustomSeriesFormMode mode;
  final ShelfSeries? initialSeries;
  final CustomSeriesFormSubmit? onCreateSubmit;
  final CustomSeriesMetadataSubmit? onEditSubmit;

  @override
  State<CustomSeriesFormSheet> createState() => _CustomSeriesFormSheetState();
}

class _CustomSeriesFormSheetState extends State<CustomSeriesFormSheet> {
  final _seriesName = TextEditingController();
  final _brand = TextEditingController();
  final _ip = TextEditingController();
  final _notes = TextEditingController();
  final _newFigure = TextEditingController();
  final _newFigureFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  final List<CustomFigureDraft> _figures = [];
  String? _coverUri;

  bool get _isCreate => widget.mode == CustomSeriesFormMode.create;

  @override
  void initState() {
    super.initState();
    final series = widget.initialSeries;
    if (series != null) {
      _seriesName.text = series.name;
      _brand.text = _brandFieldFromSeries(series);
      _ip.text = series.ipName;
      _notes.text = series.notes ?? '';
      _coverUri = series.customCoverImageUri;
    }
  }

  static String _brandFieldFromSeries(ShelfSeries series) {
    if (series.taxonomyBrandId == CustomSeriesConventions.independentBrandId) {
      return '';
    }
    return series.brand;
  }

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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isCreate) {
      if (_figures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a figure')),
        );
        return;
      }
      widget.onCreateSubmit!(
        seriesName: _seriesName.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        ipDisplayName: _ip.text.trim().isEmpty ? null : _ip.text.trim(),
        figures: List<CustomFigureDraft>.from(_figures),
        customCoverImageUri: _coverUri,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
    } else {
      widget.onEditSubmit!(
        seriesName: _seriesName.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        ipDisplayName: _ip.text.trim().isEmpty ? null : _ip.text.trim(),
        customCoverImageUri: _coverUri,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sheetScroll = CollectibleSheetScope.scrollControllerOf(context);

    return CollectibleSheetInsets(
      child: Form(
        key: _formKey,
        child: CollectibleSheetScrollView(
          controller: sheetScroll,
          header: CollectibleSheetChrome(
            editorialTitle: _isCreate ? 'New series' : 'Edit series',
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomSeriesCoverSlot(
                    imagePath: _coverUri,
                    onReplaceTap: _pickCover,
                    onClearTap: _clearCover,
                  ),
                  const SizedBox(height: FeedRhythm.sheetSectionGap + 6),
                  TextFormField(
                    controller: _seriesName,
                    style: Theme.of(context).textTheme.titleMedium,
                    textInputAction: TextInputAction.next,
                    decoration: quietCustomSeriesField(
                      scheme,
                      hintText: 'Series name',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brand,
                    textInputAction: TextInputAction.next,
                    decoration: quietCustomSeriesField(
                      scheme,
                      hintText: 'Brand',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ip,
                    textInputAction: TextInputAction.next,
                    decoration: quietCustomSeriesField(
                      scheme,
                      hintText: 'Universe',
                    ),
                  ),
                  if (_isCreate) ...[
                    const SizedBox(height: FeedRhythm.sheetSectionGap + 8),
                    FigureNameChipsEditor(
                      figures: _figures,
                      onRemoveAt: _removeAt,
                      onEditAt: _editAt,
                      addFieldController: _newFigure,
                      addFieldFocusNode: _newFigureFocus,
                      onAddSubmitted: _addFigureFromField,
                      onPickFigurePhoto: _pickFigurePhoto,
                    ),
                  ],
                  const SizedBox(height: FeedRhythm.sheetSectionGap),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: quietCustomSeriesField(
                      scheme,
                      hintText: 'Note',
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.fieldRadius,
                      ),
                    ),
                    child: Text(_isCreate ? 'Add to shelf' : 'Save changes'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
