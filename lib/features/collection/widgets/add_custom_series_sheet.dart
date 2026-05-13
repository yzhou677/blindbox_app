import 'package:flutter/material.dart';

typedef CustomSeriesFormSubmit = void Function({
  required String seriesName,
  String? brand,
  String? ipDisplayName,
  required List<String> figureNames,
  String? notes,
});

/// Minimal “new line” form — one figure per line (or comma-separated).
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
  final _figures = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _seriesName.dispose();
    _brand.dispose();
    _ip.dispose();
    _figures.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> _parseFigures() {
    final raw = _figures.text.replaceAll(',', '\n');
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final names = _parseFigures();
    if (names.isEmpty) return;
    widget.onSubmit(
      seriesName: _seriesName.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      ipDisplayName: _ip.text.trim().isEmpty ? null : _ip.text.trim(),
      figureNames: names,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'New custom line',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Name each figure on its own line (or separate with commas).',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _seriesName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Series name',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Brand (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ip,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'IP / universe label (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _figures,
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Figure names',
                  hintText: 'The Fox\nThe Bird\nThe Ghost',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (_) {
                  if (_parseFigures().isEmpty) return 'Add at least one figure name';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _save,
                child: const Text('Add to shelf'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
