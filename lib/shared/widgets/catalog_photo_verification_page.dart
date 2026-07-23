import 'dart:async';
import 'dart:convert';

import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_figure_recognition_gateway.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:blindbox_app/shared/image/local_whole_image_quality_evaluator.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_subject_selection_screen.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_browse_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;

const catalogPhotoGuidance = 'Keep the collectible centered and in focus.';

/// Optional override for success haptics (tests inject a counter; production
/// defaults to [HapticFeedback.selectionClick]).
typedef CatalogScanSelectionHaptic = void Function();

Future<void> showCatalogPhotoVerification(
  BuildContext context,
  CatalogPhotoSelection selection, {
  WholeImageQualityEvaluator evaluator =
      const LocalWholeImageQualityEvaluator(),
  CatalogSubjectLocator? locatorGateway,
  CatalogFigureRecognitionCoordinator? recognitionCoordinator,
  ValueChanged<CatalogRecognitionCandidate>? onCandidateConfirmed,
  VoidCallback? onCreateCustom,
  CatalogScanSelectionHaptic? selectionHaptic,
}) async {
  await showCatalogPhotoScanSheet(
    context,
    selection,
    evaluator: evaluator,
    locatorGateway: locatorGateway,
    recognitionCoordinator: recognitionCoordinator,
    onCandidateConfirmed: onCandidateConfirmed,
    onCreateCustom: onCreateCustom,
    selectionHaptic: selectionHaptic,
  );
}

Future<CatalogSubjectSelectionResult?> showCatalogPhotoScanSheet(
  BuildContext context,
  CatalogPhotoSelection selection, {
  WholeImageQualityEvaluator evaluator =
      const LocalWholeImageQualityEvaluator(),
  CatalogPhotoAcquirer? photoAcquirer,
  CatalogSubjectLocator? locatorGateway,
  CatalogFigureRecognitionCoordinator? recognitionCoordinator,
  ValueChanged<CatalogRecognitionCandidate>? onCandidateConfirmed,
  VoidCallback? onCreateCustom,
  CatalogScanSelectionHaptic? selectionHaptic,
}) async {
  final viewportWidth = MediaQuery.sizeOf(context).width;
  try {
    return await showModalBottomSheet<CatalogSubjectSelectionResult>(
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
          recognitionCoordinator: recognitionCoordinator,
          onCandidateConfirmed: onCandidateConfirmed,
          onCreateCustom: onCreateCustom,
          selectionHaptic: selectionHaptic,
        ),
      ),
    );
  } finally {
    // Clear any focus/keyboard left under nested Collection sheets so the
    // host tab does not keep a stale viewInsets after the scan route pops.
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

enum CatalogPhotoScanPresentationState {
  review,
  locating,
  framing,
  tooBlurry,
  recognizing,
  candidates,
  noConfidentMatch,
  recoverableFailure,
}

/// Stateful content for the continuous local-photo scan sheet.
class CatalogPhotoVerificationPage extends StatefulWidget {
  const CatalogPhotoVerificationPage({
    super.key,
    required this.selection,
    this.evaluator = const LocalWholeImageQualityEvaluator(),
    this.photoAcquirer,
    this.locatorGateway,
    this.recognitionCoordinator,
    this.onCandidateConfirmed,
    this.onCreateCustom,
    this.selectionHaptic,
  });

  final CatalogPhotoSelection selection;
  final WholeImageQualityEvaluator evaluator;
  final CatalogPhotoAcquirer? photoAcquirer;
  final CatalogSubjectLocator? locatorGateway;
  final CatalogFigureRecognitionCoordinator? recognitionCoordinator;
  final ValueChanged<CatalogRecognitionCandidate>? onCandidateConfirmed;
  final VoidCallback? onCreateCustom;
  final CatalogScanSelectionHaptic? selectionHaptic;

  @override
  State<CatalogPhotoVerificationPage> createState() =>
      _CatalogPhotoVerificationPageState();
}

class _CatalogPhotoVerificationPageState
    extends State<CatalogPhotoVerificationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stateController = AnimationController(
    vsync: this,
    duration: CollectibleMotion.crossfade,
  );
  late final Animation<double> _stateAnimation = CurvedAnimation(
    parent: _stateController,
    curve: CollectibleMotion.easeOut,
  );
  late CatalogPhotoSelection _selection;
  late final CatalogSubjectLocator _locatorGateway =
      widget.locatorGateway ?? CatalogSubjectLocatorGateway();
  CatalogFigureRecognitionCoordinator? _ownedRecognitionCoordinator;
  CatalogFigureRecognitionCoordinator get _recognitionCoordinator =>
      widget.recognitionCoordinator ??
      (_ownedRecognitionCoordinator ??= CatalogFigureRecognitionCoordinator(
        FirebaseCatalogFigureRecognitionGateway(),
      ));
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
  CatalogSubjectSelectionResult? _confirmedSelection;
  List<CatalogRecognitionCandidate> _candidates = const [];
  CatalogRecognitionFailureKind? _failureKind;
  var _candidateRevealEpoch = 0;
  var _successHapticGeneration = -1;
  static const _locatorPresentationDeadline = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _selection = widget.selection;
    _loadPreview(_selection);
  }

  @override
  void dispose() {
    _locatorGateway.cancelPending();
    widget.recognitionCoordinator?.cancelPending();
    _ownedRecognitionCoordinator?.cancelPending();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview(CatalogPhotoSelection selection) async {
    final totalTimer = Stopwatch()..start();
    _locatorGateway.cancelPending();
    widget.recognitionCoordinator?.cancelPending();
    _ownedRecognitionCoordinator?.cancelPending();
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
      _confirmedSelection = null;
      _candidates = const [];
      _failureKind = null;
    });
    _stateController.value = 0;

    Uint8List? bytes;
    Size? orientedSize;
    final readTimer = Stopwatch()..start();
    try {
      bytes = await selection.file.readAsBytes();
      _debugScanTiming(
        'client_preview',
        'image_read',
        readTimer.elapsed,
        correlationId: catalogPhotoCorrelationId(selection),
      );
      if (bytes.isNotEmpty) {
        final decodeTimer = Stopwatch()..start();
        final dimensions = await compute(_scanImageDimensions, bytes);
        _debugScanTiming(
          'client_preview',
          'image_decode_orientation',
          decodeTimer.elapsed,
          correlationId: catalogPhotoCorrelationId(selection),
          safeFields: {
            'sourceWidth': dimensions?.$1,
            'sourceHeight': dimensions?.$2,
            'originalBytes': bytes.length,
          },
        );
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
    _debugScanTiming(
      'client_preview',
      'total',
      totalTimer.elapsed,
      correlationId: catalogPhotoCorrelationId(selection),
    );
  }

  Future<void> _validateAndConfirm() async {
    if (_validating ||
        _presentationState != CatalogPhotoScanPresentationState.review) {
      return;
    }
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
      setState(() {
        _validating = false;
        _subjectSelection = catalogDefaultSubjectSelection;
        _selectionOrigin = SubjectSelectionOrigin.defaultBox;
        _initialFramingSelection = catalogDefaultSubjectSelection;
        _initialFramingOrigin = SubjectSelectionOrigin.defaultBox;
        _presentationState = CatalogPhotoScanPresentationState.framing;
      });
      _stateController.forward(from: 0);
      unawaited(_applyLocatorSuggestion(selection, generation));
      return;
    }
    setState(() {
      _validating = false;
      _obviouslyTooBlurry = true;
      _presentationState = CatalogPhotoScanPresentationState.review;
    });
  }

  Future<void> _applyLocatorSuggestion(
    CatalogPhotoSelection selection,
    int generation,
  ) async {
    final timer = Stopwatch()..start();
    CatalogSubjectLocatorResult result;
    try {
      result = await _locatorGateway.locate(selection);
    } catch (_) {
      result = const CatalogSubjectLocatorUnavailable();
    }
    if (!mounted || generation != _generation) return;
    if (timer.elapsed > _locatorPresentationDeadline ||
        result is! CatalogSubjectLocatorSuggestion ||
        !_isUsableSuggestion(result, _orientedSize) ||
        _selectionOrigin != SubjectSelectionOrigin.defaultBox ||
        _selectionInteractionActive ||
        _presentationState != CatalogPhotoScanPresentationState.framing) {
      return;
    }
    final suggestion = result;
    final transitionTimer = Stopwatch()..start();
    setState(() {
      _subjectSelection = suggestion.rect.rect;
      _selectionOrigin = SubjectSelectionOrigin.suggestedBox;
      _initialFramingSelection = suggestion.rect.rect;
      _initialFramingOrigin = SubjectSelectionOrigin.suggestedBox;
    });
    _stateController.forward(from: 0);
    _debugScanTiming(
      'client_ui',
      'locator_suggestion_transition',
      transitionTimer.elapsed,
      correlationId: catalogPhotoCorrelationId(selection),
    );
  }

  Future<void> _confirmSelection() async {
    final size = _orientedSize;
    if (size == null) return;
    final selection =
        _confirmedSelection ??
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
        );
    _confirmedSelection = selection;
    final generation = _generation;
    final transitionTimer = Stopwatch()..start();
    var transitionLogged = false;
    final result = await _recognitionCoordinator.recognize(
      selection,
      onPhase: (_) {
        if (!mounted || generation != _generation) return;
        setState(
          () => _presentationState =
              CatalogPhotoScanPresentationState.recognizing,
        );
        if (!transitionLogged) {
          transitionLogged = true;
          _debugScanTiming(
            'client_ui',
            'recognition_loading_transition',
            transitionTimer.elapsed,
            correlationId: catalogPhotoCorrelationId(_selection),
          );
        }
      },
    );
    if (!mounted || generation != _generation || result == null) return;
    final resultTransitionTimer = Stopwatch()..start();
    var emitSuccessHaptic = false;
    setState(() {
      switch (result) {
        case CatalogRecognitionTooBlurry():
          _presentationState = CatalogPhotoScanPresentationState.tooBlurry;
        case CatalogRecognitionCandidates():
          _candidates = result.candidates;
          _presentationState = CatalogPhotoScanPresentationState.candidates;
          _candidateRevealEpoch++;
          emitSuccessHaptic = result.candidates.isNotEmpty;
        case CatalogRecognitionNoConfidentMatch():
          _presentationState =
              CatalogPhotoScanPresentationState.noConfidentMatch;
        case CatalogRecognitionFailure():
          _failureKind = result.kind;
          _presentationState =
              CatalogPhotoScanPresentationState.recoverableFailure;
      }
    });
    if (emitSuccessHaptic) _emitSuccessHapticOnce(generation);
    _debugScanTiming(
      'client_ui',
      'recognition_result_transition',
      resultTransitionTimer.elapsed,
      correlationId: catalogPhotoCorrelationId(_selection),
      safeFields: {'resultType': result.runtimeType.toString()},
    );
  }

  void _emitSuccessHapticOnce(int generation) {
    if (_successHapticGeneration == generation) return;
    _successHapticGeneration = generation;
    // Tests inject [selectionHaptic] to observe; default is a no-op under the
    // test binding and selectionClick on device.
    (widget.selectionHaptic ?? HapticFeedback.selectionClick)();
  }

  void _adjustFrame() => setState(
    () => _presentationState = CatalogPhotoScanPresentationState.framing,
  );

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

  String get _title => switch (_presentationState) {
    CatalogPhotoScanPresentationState.review => 'Review photo',
    CatalogPhotoScanPresentationState.locating => 'Finding the collectible…',
    CatalogPhotoScanPresentationState.framing => 'Frame your collectible',
    CatalogPhotoScanPresentationState.recognizing =>
      'Finding your collectible…',
    CatalogPhotoScanPresentationState.tooBlurry =>
      'Selected collectible is too blurry',
    CatalogPhotoScanPresentationState.candidates =>
      'We found a few close matches',
    CatalogPhotoScanPresentationState.noConfidentMatch =>
      'We couldn’t confidently identify this collectible.',
    CatalogPhotoScanPresentationState.recoverableFailure => 'Scan unavailable',
  };

  Widget _stateGuidance(ColorScheme scheme) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return switch (_presentationState) {
      CatalogPhotoScanPresentationState.framing => _FramingGuidance(
        // Key by presentation state so origin edits rebuild in place
        // (instant AI-hint hide) instead of crossfading stale copy.
        key: const ValueKey('framing-state-guidance'),
        suggested: _selectionOrigin == SubjectSelectionOrigin.suggestedBox,
      ),
      CatalogPhotoScanPresentationState.locating => Text(
        'Looking for the main subject in your photo.',
        key: const ValueKey('locating-guidance'),
        style: style,
      ),
      CatalogPhotoScanPresentationState.recognizing => Text(
        'Comparing your photo with the Shelfy catalog.',
        style: style,
      ),
      CatalogPhotoScanPresentationState.tooBlurry => Text(
        'The selected collectible is too blurry to identify reliably.',
        style: style,
      ),
      CatalogPhotoScanPresentationState.candidates => Text(
        'Choose the collectible that looks most like yours.',
        key: const ValueKey('candidates-guidance'),
        style: style,
      ),
      CatalogPhotoScanPresentationState.noConfidentMatch => Text(
        'Try adjusting the frame, taking a closer photo, or reducing glare.',
        key: const ValueKey('no-match-guidance'),
        style: style,
      ),
      CatalogPhotoScanPresentationState.recoverableFailure => Text(
        _failureKind == CatalogRecognitionFailureKind.qualityUnavailable
            ? 'We couldn’t check photo quality.'
            : _failureKind == CatalogRecognitionFailureKind.imagePreparation
            ? 'We couldn’t prepare this selection.'
            : 'We couldn’t scan this photo right now.',
        style: style,
      ),
      _ => _GuidanceText(
        key: const ValueKey('review-guidance'),
        colorScheme: scheme,
      ),
    };
  }

  void _confirmCandidate(CatalogRecognitionCandidate candidate) {
    // Keep the scan sheet open so Series detail can stack above it and
    // system back returns to recognition results.
    widget.onCandidateConfirmed?.call(candidate);
  }

  void _createCustom() {
    final onCreate = widget.onCreateCustom;
    Navigator.pop(context, _confirmedSelection);
    if (onCreate == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => onCreate());
  }

  Widget _stateActions() {
    return switch (_presentationState) {
      CatalogPhotoScanPresentationState.framing => _FrameActions(
        key: const ValueKey('frame-actions'),
        onContinue: _confirmSelection,
        onReset: () => setState(() {
          _subjectSelection = _initialFramingSelection;
          _selectionOrigin = _initialFramingOrigin;
        }),
      ),
      CatalogPhotoScanPresentationState.locating => const _LocatingActions(
        key: ValueKey('locator-progress'),
      ),
      // Finding: crop + localized shimmer carry the wait — no competing spinner.
      CatalogPhotoScanPresentationState.recognizing => const SizedBox(
        key: ValueKey('recognition-finding-actions'),
        height: AppSpacing.sm,
      ),
      CatalogPhotoScanPresentationState.tooBlurry => _RecognitionActions(
        primaryLabel: 'Adjust Frame',
        onPrimary: _adjustFrame,
        secondary: [
          ('Retake Photo', () => _replacePhoto(CatalogPhotoSource.camera)),
          (
            'Choose Another Photo',
            () => _replacePhoto(CatalogPhotoSource.gallery),
          ),
        ],
      ),
      CatalogPhotoScanPresentationState.candidates => _CandidateActions(
        key: ValueKey('candidate-actions-$_candidateRevealEpoch'),
        candidates: _candidates,
        revealEpoch: _candidateRevealEpoch,
        onCandidateTap: _confirmCandidate,
        onCreateCustom: _createCustom,
        onTryAnother: () => _replacePhoto(CatalogPhotoSource.gallery),
      ),
      CatalogPhotoScanPresentationState.noConfidentMatch => _NoMatchActions(
        key: const ValueKey('no-match-actions'),
        onCreateCustom: _createCustom,
        onAdjustFrame: _adjustFrame,
        onTryAnother: () => _replacePhoto(CatalogPhotoSource.gallery),
      ),
      CatalogPhotoScanPresentationState.recoverableFailure =>
        _RecognitionActions(
          primaryLabel:
              _failureKind == CatalogRecognitionFailureKind.imagePreparation
              ? 'Adjust Frame'
              : 'Retry',
          onPrimary:
              _failureKind == CatalogRecognitionFailureKind.imagePreparation
              ? _adjustFrame
              : _confirmSelection,
          secondary: [
            (
              'Try Another Photo',
              () => _replacePhoto(CatalogPhotoSource.gallery),
            ),
            ('Cancel', () => Navigator.pop(context)),
          ],
        ),
      CatalogPhotoScanPresentationState.review => _ReviewActions(
        key: const ValueKey('review-actions'),
        tooBlurry: _obviouslyTooBlurry,
        validating: _validating,
        acquiring: _acquiring,
        onUsePhoto: _validateAndConfirm,
        onRetake: () => _replacePhoto(CatalogPhotoSource.camera),
        onChooseAnother: () => _replacePhoto(CatalogPhotoSource.gallery),
        onCancel: () => Navigator.pop(context),
      ),
    };
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
    final recognitionLoading =
        _presentationState == CatalogPhotoScanPresentationState.recognizing;
    final showingResults =
        _presentationState == CatalogPhotoScanPresentationState.candidates ||
        _presentationState == CatalogPhotoScanPresentationState.noConfidentMatch;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final mediaHeight = showingResults
        ? (previewHeight * 0.42).clamp(112.0, 168.0)
        : previewHeight;
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
                        duration: CollectibleMotion.crossfade,
                        switchInCurve: CollectibleMotion.easeOut,
                        switchOutCurve: CollectibleMotion.easeIn,
                        transitionBuilder: (child, animation) {
                          final offset = Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _title,
                          key: ValueKey(_presentationState),
                          style: CollectibleTypography.shelfSeriesTitle(
                            Theme.of(context).textTheme,
                            scheme,
                          ),
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
                      onPressed: () =>
                          Navigator.pop(context, _confirmedSelection),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AnimatedSwitcher(
                  duration: CollectibleMotion.crossfade,
                  switchInCurve: CollectibleMotion.easeOut,
                  child: _stateGuidance(scheme),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_previewLoading)
                SizedBox(
                  height: mediaHeight,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_previewBytes == null || _orientedSize == null)
                SizedBox(
                  height: mediaHeight,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 42,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else if (recognitionLoading || showingResults)
                AnimatedSize(
                  duration: reduceMotion
                      ? Duration.zero
                      : CollectibleMotion.sectionReveal,
                  curve: CollectibleMotion.easeOut,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    key: const ValueKey('recognition-crop-slot'),
                    height: mediaHeight,
                    width: double.infinity,
                    child: _SelectedSubjectCropPreview(
                      bytes: _previewBytes!,
                      orientedSize: _orientedSize!,
                      selection: _subjectSelection,
                      showFindingShimmer: recognitionLoading,
                    ),
                  ),
                )
              else
                CatalogSubjectSelectionEditor(
                  key: const Key('catalog-photo-shared-editor'),
                  height: mediaHeight,
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
                duration: CollectibleMotion.sectionReveal,
                switchInCurve: CollectibleMotion.easeOut,
                switchOutCurve: CollectibleMotion.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offset,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_presentationState),
                  child: _stateActions(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedSubjectCropPreview extends StatelessWidget {
  const _SelectedSubjectCropPreview({
    required this.bytes,
    required this.orientedSize,
    required this.selection,
    this.showFindingShimmer = false,
  });

  final Uint8List bytes;
  final Size orientedSize;
  final Rect selection;
  final bool showFindingShimmer;

  @override
  Widget build(BuildContext context) {
    final cropAspect =
        (orientedSize.width * selection.width) /
        (orientedSize.height * selection.height);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: showFindingShimmer
          ? 'Selected collectible being compared'
          : 'Selected collectible from your photo',
      image: true,
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final maxExtent = outerConstraints.maxHeight.isFinite
              ? outerConstraints.maxHeight
              : 220.0;
          final targetHeight = maxExtent;
          final targetWidth = (targetHeight * cropAspect).clamp(
            1.0,
            outerConstraints.maxWidth,
          );
          return Center(
            child: SizedBox(
              width: targetWidth,
              height: targetHeight,
              child: ClipRRect(
                key: const Key('recognition-selected-crop-preview'),
                borderRadius: AppRadii.cardRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final imageWidth = targetWidth / selection.width;
                        final imageHeight = targetHeight / selection.height;
                        return ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: imageWidth,
                            maxWidth: imageWidth,
                            minHeight: imageHeight,
                            maxHeight: imageHeight,
                            child: Transform.translate(
                              offset: Offset(
                                -selection.left * imageWidth,
                                -selection.top * imageHeight,
                              ),
                              child: Image.memory(
                                bytes,
                                width: imageWidth,
                                height: imageHeight,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (showFindingShimmer && !reduceMotion)
                      const IgnorePointer(
                        child: _CropFindingShimmer(
                          key: Key('recognition-finding-crop-shimmer'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Soft moving highlight limited to the crop surface — never obscures the art.
class _CropFindingShimmer extends StatefulWidget {
  const _CropFindingShimmer({super.key});

  @override
  State<_CropFindingShimmer> createState() => _CropFindingShimmerState();
}

class _CropFindingShimmerState extends State<_CropFindingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: CollectibleMotion.shimmer,
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.2 + t * 2.4, -0.2),
              end: Alignment(-0.2 + t * 2.4, 0.2),
              colors: [
                Colors.transparent,
                scheme.surface.withValues(alpha: 0.14),
                scheme.primary.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.55, 1.0],
            ),
          ),
        );
      },
    );
  }
}

void _debugScanTiming(
  String component,
  String stage,
  Duration elapsed, {
  String? correlationId,
  Map<String, Object?> safeFields = const {},
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[FigureScanTiming] ${jsonEncode({'component': component, 'correlationId': ?correlationId, 'stage': stage, 'elapsedMs': elapsed.inMicroseconds / 1000, ...safeFields})}',
  );
}

class _RecognitionActions extends StatelessWidget {
  const _RecognitionActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondary,
  });
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<(String, VoidCallback)> secondary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 52,
        child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
      ),
      for (final action in secondary) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextButton(onPressed: action.$2, child: Text(action.$1)),
        ),
      ],
    ],
  );
}

class _CandidateActions extends StatelessWidget {
  const _CandidateActions({
    super.key,
    required this.candidates,
    required this.revealEpoch,
    required this.onCandidateTap,
    required this.onCreateCustom,
    required this.onTryAnother,
  });

  final List<CatalogRecognitionCandidate> candidates;
  final int revealEpoch;
  final ValueChanged<CatalogRecognitionCandidate> onCandidateTap;
  final VoidCallback onCreateCustom;
  final VoidCallback onTryAnother;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < candidates.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _CascadeEntrance(
              key: ValueKey('recognition-cascade-$revealEpoch-$i'),
              index: i,
              revealEpoch: revealEpoch,
              child: _RecognitionCandidateCard(
                candidate: candidates[i],
                isBestMatch: i == 0,
                onTap: () => onCandidateTap(candidates[i]),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Not seeing yours?',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              key: const Key('recognition-create-custom'),
              onPressed: onCreateCustom,
              child: const Text('Create Custom Figure'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 48,
            child: TextButton(
              key: const Key('recognition-try-another'),
              onPressed: onTryAnother,
              child: const Text('Try Another Photo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CascadeEntrance extends StatefulWidget {
  const _CascadeEntrance({
    super.key,
    required this.index,
    required this.revealEpoch,
    required this.child,
  });

  final int index;
  final int revealEpoch;
  final Widget child;

  @override
  State<_CascadeEntrance> createState() => _CascadeEntranceState();
}

class _CascadeEntranceState extends State<_CascadeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CollectibleMotion.crossfade,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: CollectibleMotion.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(_fade);
  Timer? _delay;

  static Duration _startDelayFor(int index) {
    return switch (index) {
      0 => CollectibleMotion.recognitionCascadeFirst,
      1 => CollectibleMotion.recognitionCascadeSecond,
      2 => CollectibleMotion.recognitionCascadeThird,
      _ => CollectibleMotion.recognitionCascadeThird +
          Duration(milliseconds: 40 * (index - 2)),
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _armEntrance());
  }

  @override
  void didUpdateWidget(covariant _CascadeEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealEpoch != widget.revealEpoch) {
      _delay?.cancel();
      _controller.value = 0;
      _armEntrance();
    }
  }

  void _armEntrance() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _delay = Timer(_startDelayFor(widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _RecognitionCandidateCard extends StatelessWidget {
  const _RecognitionCandidateCard({
    required this.candidate,
    required this.isBestMatch,
    required this.onTap,
  });

  final CatalogRecognitionCandidate candidate;
  final bool isBestMatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semanticsLabel = isBestMatch
        ? 'Best Match, ${candidate.figureName}, ${candidate.seriesName}, ${candidate.ipName}'
        : '${candidate.figureName}, ${candidate.seriesName}, ${candidate.ipName}';

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: 'Open series',
      child: CollectibleBrowseCard(
        key: Key('recognition-candidate-${candidate.figureId}'),
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadii.figureThumbRadius,
                boxShadow: CollectibleElevation.softCard(context),
              ),
              child: ClipRRect(
                borderRadius: AppRadii.figureThumbRadius,
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: CatalogImageFromKey.legacy(
                    imageKey: candidate.imageKey,
                    name: candidate.figureName,
                    seedKey: candidate.figureId,
                    compact: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBestMatch) ...[
                    Text(
                      '✨ Best Match',
                      key: const Key('recognition-best-match-label'),
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    candidate.figureName,
                    style: CollectibleTypography.shelfSeriesTitle(
                      textTheme,
                      scheme,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    candidate.seriesName,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate.ipName,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchActions extends StatelessWidget {
  const _NoMatchActions({
    super.key,
    required this.onCreateCustom,
    required this.onAdjustFrame,
    required this.onTryAnother,
  });

  final VoidCallback onCreateCustom;
  final VoidCallback onAdjustFrame;
  final VoidCallback onTryAnother;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('recognition-create-custom'),
              onPressed: onCreateCustom,
              child: const Text('Create Custom Figure'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onAdjustFrame,
              child: const Text('Adjust Frame'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 48,
            child: TextButton(
              key: const Key('recognition-try-another'),
              onPressed: onTryAnother,
              child: const Text('Try Another Photo'),
            ),
          ),
        ],
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
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
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
