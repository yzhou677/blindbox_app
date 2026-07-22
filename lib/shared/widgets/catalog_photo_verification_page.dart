import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/local_whole_image_quality_evaluator.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_subject_selection_screen.dart';
import 'package:flutter/material.dart';

const catalogPhotoGuidance = 'Keep the collectible centered and in focus.';

Future<void> showCatalogPhotoVerification(
  BuildContext context,
  CatalogPhotoSelection selection, {
  WholeImageQualityEvaluator evaluator =
      const LocalWholeImageQualityEvaluator(),
}) async {
  final accepted = await showDialog<CatalogPhotoSelection>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) => CatalogPhotoVerificationPage(
      selection: selection,
      evaluator: evaluator,
    ),
  );
  if (accepted != null && context.mounted) {
    await Navigator.of(
      context,
    ).push(buildCatalogSubjectSelectionRoute(accepted));
  }
}

/// Stateful content for the shared floating local-photo confirmation.
class CatalogPhotoVerificationPage extends StatefulWidget {
  const CatalogPhotoVerificationPage({
    super.key,
    required this.selection,
    this.evaluator = const LocalWholeImageQualityEvaluator(),
    this.photoAcquirer,
  });

  final CatalogPhotoSelection selection;
  final WholeImageQualityEvaluator evaluator;
  final CatalogPhotoAcquirer? photoAcquirer;

  @override
  State<CatalogPhotoVerificationPage> createState() =>
      _CatalogPhotoVerificationPageState();
}

class _CatalogPhotoVerificationPageState
    extends State<CatalogPhotoVerificationPage> {
  late CatalogPhotoSelection _selection;
  Uint8List? _previewBytes;
  var _obviouslyTooBlurry = false;
  var _generation = 0;
  var _acquiring = false;
  var _previewLoading = true;
  var _validating = false;

  @override
  void initState() {
    super.initState();
    _selection = widget.selection;
    _loadPreview(_selection);
  }

  Future<void> _loadPreview(CatalogPhotoSelection selection) async {
    final generation = ++_generation;
    setState(() {
      _previewBytes = null;
      _previewLoading = true;
      _obviouslyTooBlurry = false;
      _validating = false;
    });

    Uint8List? bytes;
    try {
      bytes = await selection.file.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _selection = selection;
      _previewBytes = bytes;
      _previewLoading = false;
    });
  }

  Future<void> _validateAndConfirm() async {
    if (_validating) return;
    final generation = _generation;
    final selection = _selection;
    setState(() {
      _validating = true;
      _obviouslyTooBlurry = false;
    });
    WholeImageQualityResult result;
    try {
      result = await widget.evaluator.evaluate(selection);
    } catch (_) {
      result = const WholeImageQualityResult(
        outcome: WholeImageQualityOutcome.evaluationUnavailable,
        evaluatorVersion: 'evaluation-unavailable',
      );
    }
    if (!mounted || generation != _generation) return;
    if (result.canContinue) {
      Navigator.pop(context, selection);
      return;
    }
    setState(() {
      _validating = false;
      _obviouslyTooBlurry = true;
    });
  }

  Future<void> _replacePhoto(CatalogPhotoSource source) async {
    if (_acquiring) return;
    final rerunEvaluation = _obviouslyTooBlurry || _validating;
    setState(() => _acquiring = true);
    try {
      final selected =
          await (widget.photoAcquirer ?? ImagePickerCatalogPhotoAcquirer())
              .acquire(source);
      if (selected != null && mounted) {
        await _loadPreview(selected);
        if (rerunEvaluation && mounted) await _validateAndConfirm();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open that image. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acquiring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.37).clamp(
      170.0,
      370.0,
    );

    return Dialog(
      key: const Key('catalog-photo-confirmation'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('catalog-photo-close'),
                  tooltip: 'Close photo confirmation',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              _PhotoPreview(
                bytes: _previewBytes,
                height: previewHeight,
                loading: _previewLoading,
              ),
              const SizedBox(height: 8),
              _GuidanceText(colorScheme: scheme),
              const SizedBox(height: 14),
              if (_obviouslyTooBlurry)
                _ValidationFailureState(
                  onRetake: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.camera),
                  onChooseAnother: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.gallery),
                )
              else
                _PassActions(
                  onUsePhoto: _validating ? null : _validateAndConfirm,
                  validating: _validating,
                  onRetake: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.camera),
                  onChooseAnother: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.gallery),
                  onCancel: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceText extends StatelessWidget {
  const _GuidanceText({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: catalogPhotoGuidance,
      child: Padding(
        key: const Key('catalog-photo-guidance'),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Icon(
              Icons.center_focus_strong_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                catalogPhotoGuidance,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.bytes,
    required this.height,
    required this.loading,
  });

  final Uint8List? bytes;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('catalog-photo-preview-frame'),
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : bytes == null
              ? Icon(
                  Icons.broken_image_outlined,
                  size: 42,
                  color: scheme.onSurfaceVariant,
                )
              : Semantics(
                  image: true,
                  label: 'Selected collectible photo',
                  child: Image.memory(
                    bytes!,
                    key: const Key('catalog-photo-preview'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: 42,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ValidationFailureState extends StatelessWidget {
  const _ValidationFailureState({
    required this.onRetake,
    required this.onChooseAnother,
  });

  final VoidCallback? onRetake;
  final VoidCallback? onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('catalog-photo-validation-error'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This photo is too blurry',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hold your phone steady and keep the collectible in '
                      'focus before trying again.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('catalog-photo-retake'),
            onPressed: onRetake,
            child: const Text('Retake Photo'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            key: const Key('catalog-photo-choose-another'),
            onPressed: onChooseAnother,
            child: const Text('Choose Another Photo'),
          ),
        ),
      ],
    );
  }
}

class _PassActions extends StatelessWidget {
  const _PassActions({
    required this.onUsePhoto,
    required this.validating,
    required this.onRetake,
    required this.onChooseAnother,
    required this.onCancel,
  });

  final VoidCallback? onUsePhoto;
  final bool validating;
  final VoidCallback? onRetake;
  final VoidCallback? onChooseAnother;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: scheme.primary,
      side: BorderSide(color: scheme.outline, width: 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('catalog-photo-use'),
            onPressed: onUsePhoto,
            child: Text(validating ? 'Checking photo…' : 'Use This Photo'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            key: const Key('catalog-photo-retake'),
            onPressed: onRetake,
            style: outlinedStyle,
            child: const Text('Retake Photo'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            key: const Key('catalog-photo-choose-another'),
            onPressed: onChooseAnother,
            style: outlinedStyle,
            child: const Text('Choose Another Photo'),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: TextButton(
            key: const Key('catalog-photo-cancel'),
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}
