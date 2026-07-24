import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

const catalogDefaultSubjectSelection = Rect.fromLTWH(0.2, 0.2, 0.6, 0.6);
const _minimumSelectionExtent = 0.12;

Future<CatalogSubjectSelectionResult?> showCatalogSubjectSelectionSheet(
  BuildContext context,
  CatalogPhotoSelection selection, {
  NormalizedSubjectRect? suggestedSelection,
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
      child: CatalogSubjectSelectionScreen(
        selection: selection,
        initialSelection: suggestedSelection,
        initialOrigin: suggestedSelection == null
            ? SubjectSelectionOrigin.defaultBox
            : SubjectSelectionOrigin.suggestedBox,
      ),
    ),
  );
}

class CatalogSubjectSelectionScreen extends StatefulWidget {
  const CatalogSubjectSelectionScreen({
    super.key,
    required this.selection,
    this.initialSelection,
    this.initialOrigin = SubjectSelectionOrigin.defaultBox,
  });

  final CatalogPhotoSelection selection;
  final NormalizedSubjectRect? initialSelection;
  final SubjectSelectionOrigin initialOrigin;

  @override
  State<CatalogSubjectSelectionScreen> createState() =>
      _CatalogSubjectSelectionScreenState();
}

class _CatalogSubjectSelectionScreenState
    extends State<CatalogSubjectSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final Future<_LoadedSubjectImage?> _loadedImage = _loadImage();
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late final Animation<double> _entranceAnimation = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeOutCubic,
  );
  late Rect _selection;
  late SubjectSelectionOrigin _origin;
  var _selectionInteractionActive = false;

  @override
  void initState() {
    super.initState();
    _selection =
        widget.initialSelection?.rect ?? catalogDefaultSubjectSelection;
    _origin = widget.initialOrigin;
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<_LoadedSubjectImage?> _loadImage() async {
    try {
      final bytes = await widget.selection.file.readAsBytes();
      if (bytes.isEmpty) return null;
      final dimensions = await compute(_orientedDimensions, bytes);
      if (dimensions == null) return null;
      if (mounted) _entranceController.forward(from: 0);
      return _LoadedSubjectImage(
        bytes: bytes,
        orientedSize: Size(dimensions.$1.toDouble(), dimensions.$2.toDouble()),
      );
    } catch (_) {
      return null;
    }
  }

  void _setSelection(Rect selection, SubjectSelectionOrigin origin) {
    setState(() {
      _selection = selection;
      _origin = origin;
    });
  }

  void _confirm(_LoadedSubjectImage loaded) {
    final size = loaded.orientedSize;
    Navigator.pop(
      context,
      CatalogSubjectSelectionResult(
        photo: widget.selection,
        normalizedRect: NormalizedSubjectRect.fromRect(_selection),
        sourceImageRect: Rect.fromLTRB(
          _selection.left * size.width,
          _selection.top * size.height,
          _selection.right * size.width,
          _selection.bottom * size.height,
        ),
        orientedSourceSize: size,
        origin: _origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('subject-selection-sheet'),
      color: scheme.surface,
      elevation: 12,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              key: const Key('subject-selection-drag-handle'),
              height: 18,
              width: double.infinity,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: FadeTransition(
                      opacity: _entranceAnimation,
                      child: Text(
                        'Frame your collectible',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('subject-selection-close'),
                    tooltip: 'Close subject framing',
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
            Expanded(
              child: FutureBuilder<_LoadedSubjectImage?>(
                future: _loadedImage,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final loaded = snapshot.data;
                  if (loaded == null) {
                    return Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 44,
                        color: scheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final viewportHeight = (constraints.maxHeight - 208)
                          .clamp(220.0, 680.0);
                      return SingleChildScrollView(
                        physics: _selectionInteractionActive
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: FadeTransition(
                                opacity: _entranceAnimation,
                                child: Text(
                                  'Move and resize the frame until it fits your collectible.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                            if (_origin ==
                                SubjectSelectionOrigin.suggestedBox) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: _AiSuggestionStatus(colorScheme: scheme),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            _SubjectSelectionViewport(
                              height: viewportHeight,
                              image: loaded,
                              normalizedSelection: _selection,
                              onSelectionChanged: _setSelection,
                              entranceAnimation: _entranceAnimation,
                              interactionActive: _selectionInteractionActive,
                              onInteractionChanged: (active) {
                                if (_selectionInteractionActive == active) {
                                  return;
                                }
                                setState(
                                  () => _selectionInteractionActive = active,
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton(
                              key: const Key('subject-selection-confirm'),
                              onPressed: () => _confirm(loaded),
                              style: FilledButton.styleFrom(
                                elevation: 4,
                                minimumSize: const Size.fromHeight(56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Continue'),
                            ),
                            TextButton.icon(
                              key: const Key('subject-selection-reset'),
                              onPressed: () => _setSelection(
                                catalogDefaultSubjectSelection,
                                SubjectSelectionOrigin.defaultBox,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant,
                                minimumSize: const Size.fromHeight(48),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 17),
                              label: const Text('Reset Selection'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSuggestionStatus extends StatelessWidget {
  const _AiSuggestionStatus({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('subject-selection-ai-suggestion'),
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'AI suggested this frame. Adjust if needed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadedSubjectImage {
  const _LoadedSubjectImage({required this.bytes, required this.orientedSize});
  final Uint8List bytes;
  final Size orientedSize;
}

/// Shared photo editor used by both the continuous scan sheet and the
/// standalone subject-selection harness.
class CatalogSubjectSelectionEditor extends StatelessWidget {
  const CatalogSubjectSelectionEditor({
    super.key,
    required this.height,
    required this.bytes,
    required this.orientedSize,
    required this.normalizedSelection,
    required this.onSelectionChanged,
    required this.onInteractionChanged,
    required this.selectionAnimation,
    required this.interactionActive,
    required this.selectionEnabled,
  });

  final double height;
  final Uint8List bytes;
  final Size orientedSize;
  final Rect normalizedSelection;
  final void Function(Rect, SubjectSelectionOrigin) onSelectionChanged;
  final ValueChanged<bool> onInteractionChanged;
  final Animation<double> selectionAnimation;
  final bool interactionActive;
  final bool selectionEnabled;

  @override
  Widget build(BuildContext context) => _SubjectSelectionViewport(
    height: height,
    image: _LoadedSubjectImage(bytes: bytes, orientedSize: orientedSize),
    normalizedSelection: normalizedSelection,
    onSelectionChanged: onSelectionChanged,
    onInteractionChanged: onInteractionChanged,
    entranceAnimation: selectionAnimation,
    interactionActive: interactionActive,
    selectionEnabled: selectionEnabled,
  );
}

class _SubjectSelectionViewport extends StatefulWidget {
  const _SubjectSelectionViewport({
    required this.height,
    required this.image,
    required this.normalizedSelection,
    required this.onSelectionChanged,
    required this.onInteractionChanged,
    required this.entranceAnimation,
    required this.interactionActive,
    this.selectionEnabled = true,
  });

  final double height;
  final _LoadedSubjectImage image;
  final Rect normalizedSelection;
  final void Function(Rect, SubjectSelectionOrigin) onSelectionChanged;
  final ValueChanged<bool> onInteractionChanged;
  final Animation<double> entranceAnimation;
  final bool interactionActive;
  final bool selectionEnabled;

  @override
  State<_SubjectSelectionViewport> createState() =>
      _SubjectSelectionViewportState();
}

class _SubjectSelectionViewportState extends State<_SubjectSelectionViewport> {
  Offset? _redrawAnchor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = constraints.biggest;
          final fitted = applyBoxFit(
            BoxFit.contain,
            widget.image.orientedSize,
            viewportSize,
          );
          final imageRect = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & viewportSize,
          );
          final selectionRect = Rect.fromLTRB(
            imageRect.left + widget.normalizedSelection.left * imageRect.width,
            imageRect.top + widget.normalizedSelection.top * imageRect.height,
            imageRect.left + widget.normalizedSelection.right * imageRect.width,
            imageRect.top +
                widget.normalizedSelection.bottom * imageRect.height,
          );

          return AnimatedBuilder(
            animation: widget.entranceAnimation,
            builder: (context, _) {
              final progress = widget.entranceAnimation.value;
              final visualSelectionRect = Rect.fromCenter(
                center: selectionRect.center,
                width: selectionRect.width * (0.97 + (0.03 * progress)),
                height: selectionRect.height * (0.97 + (0.03 * progress)),
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: scheme.surfaceContainerLow,
                  child: Stack(
                    key: const Key('subject-selection-viewport'),
                    children: [
                      Positioned.fromRect(
                        rect: imageRect,
                        child: Image.memory(
                          widget.image.bytes,
                          key: const Key('subject-selection-image'),
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                      if (widget.selectionEnabled)
                        Positioned.fill(
                          child: GestureDetector(
                            key: const Key('subject-selection-redraw-area'),
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) {
                              final point = _normalizedPoint(
                                details.localPosition,
                                imageRect,
                              );
                              if (point == null ||
                                  selectionRect.contains(
                                    details.localPosition,
                                  )) {
                                return;
                              }
                              widget.onInteractionChanged(true);
                              _redrawAnchor = point;
                              widget.onSelectionChanged(
                                _minimumRectAt(point),
                                SubjectSelectionOrigin.userRedrawn,
                              );
                            },
                            onPanUpdate: (details) {
                              final anchor = _redrawAnchor;
                              final point = _normalizedPoint(
                                details.localPosition,
                                imageRect,
                              );
                              if (anchor == null || point == null) return;
                              widget.onSelectionChanged(
                                _rectBetween(anchor, point),
                                SubjectSelectionOrigin.userRedrawn,
                              );
                            },
                            onPanEnd: (_) {
                              _redrawAnchor = null;
                              widget.onInteractionChanged(false);
                            },
                            onPanCancel: () {
                              _redrawAnchor = null;
                              widget.onInteractionChanged(false);
                            },
                          ),
                        ),
                      if (widget.selectionEnabled)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const Key('subject-selection-overlay'),
                              painter: _SelectionOverlayPainter(
                                imageRect: imageRect,
                                selectionRect: visualSelectionRect,
                                color: scheme.primary,
                                opacity: progress,
                              ),
                            ),
                          ),
                        ),
                      if (widget.selectionEnabled)
                        Positioned.fromRect(
                          rect: selectionRect,
                          child: Listener(
                            key: const Key('subject-selection-box'),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) =>
                                widget.onInteractionChanged(true),
                            onPointerUp: (_) =>
                                widget.onInteractionChanged(false),
                            onPointerCancel: (_) =>
                                widget.onInteractionChanged(false),
                            onPointerMove: (details) {
                              final dx = details.delta.dx / imageRect.width;
                              final dy = details.delta.dy / imageRect.height;
                              final moved = widget.normalizedSelection.shift(
                                Offset(dx, dy),
                              );
                              widget.onSelectionChanged(
                                moved.shift(
                                  Offset(
                                    moved.left < 0
                                        ? -moved.left
                                        : moved.right > 1
                                        ? 1 - moved.right
                                        : 0,
                                    moved.top < 0
                                        ? -moved.top
                                        : moved.bottom > 1
                                        ? 1 - moved.bottom
                                        : 0,
                                  ),
                                ),
                                SubjectSelectionOrigin.userEdited,
                              );
                            },
                          ),
                        ),
                      if (widget.selectionEnabled)
                        for (final corner in _SelectionCorner.values)
                          _ResizeHandle(
                            corner: corner,
                            selectionRect: visualSelectionRect,
                            imageRect: imageRect,
                            normalizedSelection: widget.normalizedSelection,
                            color: scheme.primary,
                            onSelectionChanged: widget.onSelectionChanged,
                            onInteractionChanged: widget.onInteractionChanged,
                            entranceOpacity: progress,
                            interactionActive: widget.interactionActive,
                          ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Offset? _normalizedPoint(Offset local, Rect imageRect) {
  if (!imageRect.contains(local)) return null;
  return Offset(
    ((local.dx - imageRect.left) / imageRect.width).clamp(0, 1),
    ((local.dy - imageRect.top) / imageRect.height).clamp(0, 1),
  );
}

Rect _minimumRectAt(Offset point) {
  final half = _minimumSelectionExtent / 2;
  final left = (point.dx - half).clamp(0.0, 1 - _minimumSelectionExtent);
  final top = (point.dy - half).clamp(0.0, 1 - _minimumSelectionExtent);
  return Rect.fromLTWH(
    left,
    top,
    _minimumSelectionExtent,
    _minimumSelectionExtent,
  );
}

Rect _rectBetween(Offset a, Offset b) {
  var left = a.dx < b.dx ? a.dx : b.dx;
  var right = a.dx > b.dx ? a.dx : b.dx;
  var top = a.dy < b.dy ? a.dy : b.dy;
  var bottom = a.dy > b.dy ? a.dy : b.dy;
  if (right - left < _minimumSelectionExtent) {
    right = (left + _minimumSelectionExtent).clamp(0, 1);
    left = (right - _minimumSelectionExtent).clamp(0, 1);
  }
  if (bottom - top < _minimumSelectionExtent) {
    bottom = (top + _minimumSelectionExtent).clamp(0, 1);
    top = (bottom - _minimumSelectionExtent).clamp(0, 1);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

enum _SelectionCorner { topLeft, topRight, bottomLeft, bottomRight }

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.corner,
    required this.selectionRect,
    required this.imageRect,
    required this.normalizedSelection,
    required this.color,
    required this.onSelectionChanged,
    required this.onInteractionChanged,
    required this.entranceOpacity,
    required this.interactionActive,
  });

  final _SelectionCorner corner;
  final Rect selectionRect;
  final Rect imageRect;
  final Rect normalizedSelection;
  final Color color;
  final void Function(Rect, SubjectSelectionOrigin) onSelectionChanged;
  final ValueChanged<bool> onInteractionChanged;
  final double entranceOpacity;
  final bool interactionActive;

  @override
  Widget build(BuildContext context) {
    final center = switch (corner) {
      _SelectionCorner.topLeft => selectionRect.topLeft,
      _SelectionCorner.topRight => selectionRect.topRight,
      _SelectionCorner.bottomLeft => selectionRect.bottomLeft,
      _SelectionCorner.bottomRight => selectionRect.bottomRight,
    };
    return Positioned(
      left: center.dx - 22,
      top: center.dy - 22,
      width: 44,
      height: 44,
      child: Listener(
        key: Key('subject-selection-handle-${corner.name}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onInteractionChanged(true),
        onPointerUp: (_) => onInteractionChanged(false),
        onPointerCancel: (_) => onInteractionChanged(false),
        onPointerMove: (details) {
          final dx = details.delta.dx / imageRect.width;
          final dy = details.delta.dy / imageRect.height;
          var left = normalizedSelection.left;
          var top = normalizedSelection.top;
          var right = normalizedSelection.right;
          var bottom = normalizedSelection.bottom;
          if (corner == _SelectionCorner.topLeft ||
              corner == _SelectionCorner.bottomLeft) {
            left = (left + dx).clamp(0, right - _minimumSelectionExtent);
          } else {
            right = (right + dx).clamp(left + _minimumSelectionExtent, 1);
          }
          if (corner == _SelectionCorner.topLeft ||
              corner == _SelectionCorner.topRight) {
            top = (top + dy).clamp(0, bottom - _minimumSelectionExtent);
          } else {
            bottom = (bottom + dy).clamp(top + _minimumSelectionExtent, 1);
          }
          onSelectionChanged(
            Rect.fromLTRB(left, top, right, bottom),
            SubjectSelectionOrigin.userEdited,
          );
        },
        child: Opacity(
          opacity: entranceOpacity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: interactionActive ? 17 : 14,
              height: interactionActive ? 17 : 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(color: Colors.white54, blurRadius: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionOverlayPainter extends CustomPainter {
  const _SelectionOverlayPainter({
    required this.imageRect,
    required this.selectionRect,
    required this.color,
    required this.opacity,
  });

  final Rect imageRect;
  final Rect selectionRect;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageRect)
      ..addRect(selectionRect);
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.3 * opacity),
    );
    final roundedSelection = RRect.fromRectAndRadius(
      selectionRect,
      const Radius.circular(12),
    );
    canvas.drawRRect(
      roundedSelection,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawRRect(
      roundedSelection,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) =>
      imageRect != oldDelegate.imageRect ||
      selectionRect != oldDelegate.selectionRect ||
      color != oldDelegate.color ||
      opacity != oldDelegate.opacity;
}

(int, int)? _orientedDimensions(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = image.bakeOrientation(decoded);
  return (oriented.width, oriented.height);
}
