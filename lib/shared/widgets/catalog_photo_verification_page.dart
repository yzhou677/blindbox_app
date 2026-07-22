import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:blindbox_app/shared/image/local_whole_image_quality_evaluator.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_subject_selection_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

const catalogPhotoGuidance = 'Keep the collectible centered and in focus.';

Future<void> showCatalogPhotoVerification(
  BuildContext context,
  CatalogPhotoSelection selection, {
  WholeImageQualityEvaluator evaluator =
      const LocalWholeImageQualityEvaluator(),
  CatalogSubjectLocator? locatorGateway,
}) async {
  await showCatalogPhotoScanSheet(
    context,
    selection,
    evaluator: evaluator,
    locatorGateway: locatorGateway,
  );
}

Future<CatalogSubjectSelectionResult?> showCatalogPhotoScanSheet(
  BuildContext context,
  CatalogPhotoSelection selection, {
  WholeImageQualityEvaluator evaluator =
      const LocalWholeImageQualityEvaluator(),
  CatalogPhotoAcquirer? photoAcquirer,
  CatalogSubjectLocator? locatorGateway,
}) {
  final viewportWidth = MediaQuery.sizeOf(context).width;
  return showModalBottomSheet<CatalogSubjectSelectionResult>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: 0.36),
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: BoxConstraints(
      minWidth: viewportWidth,
      maxWidth: viewportWidth,
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      alignment: Alignment.bottomCenter,
      child: CatalogPhotoVerificationPage(
        selection: selection,
        evaluator: evaluator,
        photoAcquirer: photoAcquirer,
        locatorGateway: locatorGateway,
      ),
    ),
  );
}

enum CatalogPhotoScanPresentationState { review, locating, framing }

/// Stateful content for the continuous local-photo scan sheet.
class CatalogPhotoVerificationPage extends StatefulWidget {
  const CatalogPhotoVerificationPage({
    super.key,
    required this.selection,
    this.evaluator = const LocalWholeImageQualityEvaluator(),
    this.photoAcquirer,
    this.locatorGateway,
  });

  final CatalogPhotoSelection selection;
  final WholeImageQualityEvaluator evaluator;
  final CatalogPhotoAcquirer? photoAcquirer;
  final CatalogSubjectLocator? locatorGateway;

  @override
  State<CatalogPhotoVerificationPage> createState() =>
      _CatalogPhotoVerificationPageState();
}

class _CatalogPhotoVerificationPageState
    extends State<CatalogPhotoVerificationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stateController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _stateAnimation = CurvedAnimation(
    parent: _stateController,
    curve: Curves.easeOutCubic,
  );
  late CatalogPhotoSelection _selection;
  late final CatalogSubjectLocator _locatorGateway =
      widget.locatorGateway ?? CatalogSubjectLocatorGateway();
  Uint8List? _previewBytes;
  Size? _orientedSize;
  Rect _subjectSelection = catalogDefaultSubjectSelection;
  SubjectSelectionOrigin _selectionOrigin = SubjectSelectionOrigin.defaultBox;
  Rect _initialFramingSelection = catalogDefaultSubjectSelection;
  SubjectSelectionOrigin _initialFramingOrigin =
      SubjectSelectionOrigin.defaultBox;
  CatalogPhotoScanPresentationState _presentationState =
      CatalogPhotoScanPresentationState.review;
  var _selectionInteractionActive = false;
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

  @override
  void dispose() {
    _locatorGateway.cancelPending();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview(CatalogPhotoSelection selection) async {
    _locatorGateway.cancelPending();
    final generation = ++_generation;
    setState(() {
      _previewBytes = null;
      _orientedSize = null;
      _previewLoading = true;
      _obviouslyTooBlurry = false;
      _validating = false;
      _presentationState = CatalogPhotoScanPresentationState.review;
      _subjectSelection = catalogDefaultSubjectSelection;
      _selectionOrigin = SubjectSelectionOrigin.defaultBox;
      _initialFramingSelection = catalogDefaultSubjectSelection;
      _initialFramingOrigin = SubjectSelectionOrigin.defaultBox;
    });
    _stateController.value = 0;

    Uint8List? bytes;
    Size? orientedSize;
    try {
      bytes = await selection.file.readAsBytes();
      if (bytes.isNotEmpty) {
        final dimensions = await compute(_scanImageDimensions, bytes);
        if (dimensions != null) {
          orientedSize = Size(
            dimensions.$1.toDouble(),
            dimensions.$2.toDouble(),
          );
        }
      }
    } catch (_) {
      bytes = null;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _selection = selection;
      _previewBytes = bytes;
      _orientedSize = orientedSize;
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
      _presentationState = CatalogPhotoScanPresentationState.locating;
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
      CatalogSubjectLocatorResult locatorResult;
      try {
        locatorResult = await _locatorGateway.locate(selection);
      } catch (_) {
        locatorResult = const CatalogSubjectLocatorUnavailable();
      }
      if (!mounted || generation != _generation) return;
      final suggestion = locatorResult is CatalogSubjectLocatorSuggestion &&
              _isUsableSuggestion(locatorResult, _orientedSize)
          ? locatorResult
          : null;
      final selectionRect = suggestion?.rect.rect ??
          catalogDefaultSubjectSelection;
      final origin = suggestion == null
          ? SubjectSelectionOrigin.defaultBox
          : SubjectSelectionOrigin.suggestedBox;
      setState(() {
        _validating = false;
        _subjectSelection = selectionRect;
        _selectionOrigin = origin;
        _initialFramingSelection = selectionRect;
        _initialFramingOrigin = origin;
        _presentationState = CatalogPhotoScanPresentationState.framing;
      });
      _stateController.forward(from: 0);
      return;
    }
    setState(() {
      _validating = false;
      _obviouslyTooBlurry = true;
      _presentationState = CatalogPhotoScanPresentationState.review;
    });
  }

  void _confirmSelection() {
    final size = _orientedSize;
    if (size == null) return;
    Navigator.pop(
      context,
      CatalogSubjectSelectionResult(
        photo: _selection,
        normalizedRect: NormalizedSubjectRect.fromRect(_subjectSelection),
        sourceImageRect: Rect.fromLTRB(
          _subjectSelection.left * size.width,
          _subjectSelection.top * size.height,
          _subjectSelection.right * size.width,
          _subjectSelection.bottom * size.height,
        ),
        orientedSourceSize: size,
        origin: _selectionOrigin,
      ),
    );
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
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.4).clamp(
      220.0,
      380.0,
    );
    final framing =
        _presentationState == CatalogPhotoScanPresentationState.framing;
    final locating =
        _presentationState == CatalogPhotoScanPresentationState.locating;

    return Material(
      key: const Key('catalog-photo-confirmation'),
      color: scheme.surface,
      elevation: 12,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: _selectionInteractionActive
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const Key('subject-selection-drag-handle'),
                height: 18,
                child: Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, ?current],
                        ),
                        child: Text(
                          framing
                              ? 'Frame your collectible'
                              : locating
                              ? 'Finding the collectible…'
                              : 'Review photo',
                          key: ValueKey(_presentationState),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('catalog-photo-close'),
                      tooltip: 'Close photo scan',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: framing
                      ? _FramingGuidance(
                          key: ValueKey(_selectionOrigin),
                          suggested: _selectionOrigin ==
                              SubjectSelectionOrigin.suggestedBox,
                        )
                      : locating
                      ? Text(
                          'Looking for the main subject in your photo.',
                          key: const ValueKey('locating-guidance'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : _GuidanceText(
                          key: const ValueKey('review-guidance'),
                          colorScheme: scheme,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_previewLoading)
                SizedBox(
                  height: previewHeight,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_previewBytes == null || _orientedSize == null)
                SizedBox(
                  height: previewHeight,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 42,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                CatalogSubjectSelectionEditor(
                  key: const Key('catalog-photo-shared-editor'),
                  height: previewHeight,
                  bytes: _previewBytes!,
                  orientedSize: _orientedSize!,
                  normalizedSelection: _subjectSelection,
                  onSelectionChanged: (selection, origin) {
                    setState(() {
                      _subjectSelection = selection;
                      _selectionOrigin = origin;
                    });
                  },
                  onInteractionChanged: (active) {
                    if (_selectionInteractionActive == active) return;
                    setState(() => _selectionInteractionActive = active);
                  },
                  selectionAnimation: _stateAnimation,
                  interactionActive: _selectionInteractionActive,
                  selectionEnabled: framing,
                ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                ),
                child: framing
                    ? _FrameActions(
                        key: const ValueKey('frame-actions'),
                        onContinue: _confirmSelection,
                        onReset: () => setState(() {
                          _subjectSelection = _initialFramingSelection;
                          _selectionOrigin = _initialFramingOrigin;
                        }),
                      )
                    : locating
                    ? const _LocatingActions(
                        key: ValueKey('locating-actions'),
                      )
                    : _ReviewActions(
                        key: const ValueKey('review-actions'),
                        tooBlurry: _obviouslyTooBlurry,
                        validating: _validating,
                        acquiring: _acquiring,
                        onUsePhoto: _validateAndConfirm,
                        onRetake: () =>
                            _replacePhoto(CatalogPhotoSource.camera),
                        onChooseAnother: () =>
                            _replacePhoto(CatalogPhotoSource.gallery),
                        onCancel: () => Navigator.pop(context),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceText extends StatelessWidget {
  const _GuidanceText({super.key, required this.colorScheme});

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

class _FramingGuidance extends StatelessWidget {
  const _FramingGuidance({super.key, required this.suggested});

  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Move and resize the frame until it fits your collectible.',
          key: const ValueKey('framing-guidance'),
          style: style,
        ),
        if (suggested) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            key: const Key('subject-selection-ai-suggestion'),
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'AI suggested this frame. Adjust if needed.',
                  style: style,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LocatingActions extends StatelessWidget {
  const _LocatingActions({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(
      child: SizedBox(
        key: Key('subject-locator-progress'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    ),
  );
}

bool _isUsableSuggestion(
  CatalogSubjectLocatorSuggestion suggestion,
  Size? originalOrientedSize,
) {
  final rect = suggestion.rect.rect;
  final dimensions = suggestion.orientedSize;
  if (!rect.left.isFinite ||
      !rect.top.isFinite ||
      !rect.width.isFinite ||
      !rect.height.isFinite ||
      !dimensions.width.isFinite ||
      !dimensions.height.isFinite ||
      rect.left < 0 ||
      rect.top < 0 ||
      rect.width <= 0 ||
      rect.height <= 0 ||
      rect.right > 1 ||
      rect.bottom > 1 ||
      dimensions.width <= 0 ||
      dimensions.height <= 0 ||
      originalOrientedSize == null) {
    return false;
  }
  const aspectTolerance = 0.02;
  final locatorAspect = dimensions.width / dimensions.height;
  final originalAspect =
      originalOrientedSize.width / originalOrientedSize.height;
  return (locatorAspect - originalAspect).abs() <= aspectTolerance;
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    super.key,
    required this.tooBlurry,
    required this.validating,
    required this.acquiring,
    required this.onUsePhoto,
    required this.onRetake,
    required this.onChooseAnother,
    required this.onCancel,
  });

  final bool tooBlurry;
  final bool validating;
  final bool acquiring;
  final VoidCallback onUsePhoto;
  final VoidCallback onRetake;
  final VoidCallback onChooseAnother;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => tooBlurry
      ? _ValidationFailureState(
          onRetake: acquiring ? null : onRetake,
          onChooseAnother: acquiring ? null : onChooseAnother,
        )
      : _PassActions(
          onUsePhoto: validating ? null : onUsePhoto,
          validating: validating,
          onRetake: acquiring ? null : onRetake,
          onChooseAnother: acquiring ? null : onChooseAnother,
          onCancel: onCancel,
        );
}

class _FrameActions extends StatelessWidget {
  const _FrameActions({
    super.key,
    required this.onContinue,
    required this.onReset,
  });

  final VoidCallback onContinue;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('subject-selection-confirm'),
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            elevation: 4,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
          child: const Text('Continue'),
        ),
        TextButton.icon(
          key: const Key('subject-selection-reset'),
          onPressed: onReset,
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Reset Selection'),
        ),
      ],
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

(int, int)? _scanImageDimensions(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = image.bakeOrientation(decoded);
  return (oriented.width, oriented.height);
}
