import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/local_whole_image_quality_evaluator.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_photo_placeholder.dart';
import 'package:flutter/material.dart';

const catalogPhotoGuidance = 'Keep the collectible centered and in focus.';

Future<void> showCatalogPhotoVerification(
  BuildContext context,
  CatalogPhotoSelection selection,
) async {
  final accepted = await showDialog<CatalogPhotoSelection>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) => CatalogPhotoVerificationPage(selection: selection),
  );
  if (accepted != null && context.mounted) {
    showCatalogPhotoPlaceholder(context, accepted);
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
  WholeImageQualityResult? _quality;
  var _generation = 0;
  var _acquiring = false;

  @override
  void initState() {
    super.initState();
    _selection = widget.selection;
    _evaluate(_selection);
  }

  Future<void> _evaluate(CatalogPhotoSelection selection) async {
    final generation = ++_generation;
    setState(() {
      _previewBytes = null;
      _quality = null;
    });

    Uint8List? bytes;
    try {
      bytes = await selection.file.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    final quality = await widget.evaluator.evaluate(selection);
    if (!mounted || generation != _generation) return;
    setState(() {
      _selection = selection;
      _previewBytes = bytes;
      _quality = quality;
    });
  }

  Future<void> _replacePhoto(CatalogPhotoSource source) async {
    if (_acquiring) return;
    setState(() => _acquiring = true);
    try {
      final selected =
          await (widget.photoAcquirer ?? ImagePickerCatalogPhotoAcquirer())
              .acquire(source);
      if (selected != null && mounted) await _evaluate(selected);
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
    final result = _quality;
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      190.0,
      420.0,
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
              _PhotoPreview(bytes: _previewBytes, height: previewHeight),
              const SizedBox(height: 14),
              _GuidanceText(colorScheme: scheme),
              const SizedBox(height: 16),
              if (result == null)
                const _CheckingState()
              else if (result.status == WholeImageQualityStatus.obviouslyBlurry)
                _RecoveryState(
                  icon: Icons.motion_photos_off_outlined,
                  title: 'Photo is too blurry',
                  body:
                      'Hold your phone steady and keep the collectible in focus before taking another photo.',
                  onRetake: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.camera),
                  onChooseAnother: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.gallery),
                )
              else if (result.status == WholeImageQualityStatus.invalid)
                _RecoveryState(
                  icon: Icons.broken_image_outlined,
                  title: 'Couldn’t use this photo',
                  body: 'Choose a readable photo and try again.',
                  onRetake: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.camera),
                  onChooseAnother: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.gallery),
                )
              else
                _PassActions(
                  onUsePhoto: () => Navigator.pop(context, _selection),
                  onRetake: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.camera),
                  onChooseAnother: _acquiring
                      ? null
                      : () => _replacePhoto(CatalogPhotoSource.gallery),
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
  const _PhotoPreview({required this.bytes, required this.height});

  final Uint8List? bytes;
  final double height;

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
          child: bytes == null
              ? const Center(child: CircularProgressIndicator())
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

class _CheckingState extends StatelessWidget {
  const _CheckingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Checking photo…'));
  }
}

class _RecoveryState extends StatelessWidget {
  const _RecoveryState({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRetake,
    required this.onChooseAnother,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetake;
  final VoidCallback? onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 34, color: scheme.onSurfaceVariant),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('catalog-photo-retake'),
            onPressed: onRetake,
            child: const Text('Retake Photo'),
          ),
        ),
        TextButton(
          key: const Key('catalog-photo-choose-another'),
          onPressed: onChooseAnother,
          child: const Text('Choose Another Photo'),
        ),
      ],
    );
  }
}

class _PassActions extends StatelessWidget {
  const _PassActions({
    required this.onUsePhoto,
    required this.onRetake,
    required this.onChooseAnother,
  });

  final VoidCallback onUsePhoto;
  final VoidCallback? onRetake;
  final VoidCallback? onChooseAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('catalog-photo-use'),
          onPressed: onUsePhoto,
          child: const Text('Use This Photo'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('catalog-photo-retake'),
                onPressed: onRetake,
                child: const Text('Retake Photo'),
              ),
            ),
            Expanded(
              child: TextButton(
                key: const Key('catalog-photo-choose-another'),
                onPressed: onChooseAnother,
                child: const Text('Choose Another'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
