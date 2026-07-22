import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

const catalogSubjectSelectionRouteName = '/scan/subject-selection';
const _defaultSelection = Rect.fromLTWH(0.2, 0.2, 0.6, 0.6);
const _minimumSelectionExtent = 0.12;

Route<CatalogSubjectSelectionResult> buildCatalogSubjectSelectionRoute(
  CatalogPhotoSelection selection, {
  NormalizedSubjectRect? suggestedSelection,
}) => MaterialPageRoute<CatalogSubjectSelectionResult>(
  settings: const RouteSettings(name: catalogSubjectSelectionRouteName),
  builder: (_) => CatalogSubjectSelectionScreen(
    selection: selection,
    initialSelection: suggestedSelection,
    initialOrigin: suggestedSelection == null
        ? SubjectSelectionOrigin.defaultBox
        : SubjectSelectionOrigin.suggestedBox,
  ),
);

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
    _selection = widget.initialSelection?.rect ?? _defaultSelection;
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 0,
        title: FadeTransition(
          opacity: _entranceAnimation,
          child: Text(
            'Frame your collectible',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
      body: SafeArea(
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
              builder: (context, constraints) => SingleChildScrollView(
                physics: _selectionInteractionActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                        opacity: _entranceAnimation,
                        child: Text(
                          'Move and resize the frame until it fits your collectible.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.82,
                                ),
                                height: 1.22,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SubjectSelectionViewport(
                        image: loaded,
                        normalizedSelection: _selection,
                        onSelectionChanged: _setSelection,
                        entranceAnimation: _entranceAnimation,
                        interactionActive: _selectionInteractionActive,
                        onInteractionChanged: (active) {
                          if (_selectionInteractionActive == active) return;
                          setState(() => _selectionInteractionActive = active);
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          key: const Key('subject-selection-confirm'),
                          onPressed: () => _confirm(loaded),
                          style: FilledButton.styleFrom(
                            elevation: 3,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: TextButton.icon(
                          key: const Key('subject-selection-reset'),
                          onPressed: () => _setSelection(
                            _defaultSelection,
                            SubjectSelectionOrigin.defaultBox,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 19),
                          label: const Text('Reset Selection'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadedSubjectImage {
  const _LoadedSubjectImage({required this.bytes, required this.orientedSize});
  final Uint8List bytes;
  final Size orientedSize;
}

class _SubjectSelectionViewport extends StatefulWidget {
  const _SubjectSelectionViewport({
    required this.image,
    required this.normalizedSelection,
    required this.onSelectionChanged,
    required this.onInteractionChanged,
    required this.entranceAnimation,
    required this.interactionActive,
  });

  final _LoadedSubjectImage image;
  final Rect normalizedSelection;
  final void Function(Rect, SubjectSelectionOrigin) onSelectionChanged;
  final ValueChanged<bool> onInteractionChanged;
  final Animation<double> entranceAnimation;
  final bool interactionActive;

  @override
  State<_SubjectSelectionViewport> createState() =>
      _SubjectSelectionViewportState();
}

class _SubjectSelectionViewportState extends State<_SubjectSelectionViewport> {
  Offset? _redrawAnchor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 3 / 4,
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
                  color: scheme.surfaceContainerHighest,
                  child: Stack(
                    key: const Key('subject-selection-viewport'),
                    children: [
                      Positioned.fromRect(
                        rect: imageRect,
                        child: FadeTransition(
                          opacity: widget.entranceAnimation,
                          child: Image.memory(
                            widget.image.bytes,
                            key: const Key('subject-selection-image'),
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
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
                                selectionRect.contains(details.localPosition)) {
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
              width: interactionActive ? 17 : 15,
              height: interactionActive ? 17 : 15,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 3),
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
      Paint()..color = Colors.black.withValues(alpha: 0.36 * opacity),
    );
    final roundedSelection = RRect.fromRectAndRadius(
      selectionRect,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      roundedSelection,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      roundedSelection,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
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
