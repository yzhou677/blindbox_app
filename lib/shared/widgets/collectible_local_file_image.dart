import 'dart:io';

import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:flutter/material.dart';

/// Paths we've logged failures for (one debug line per path per app session).
final Set<String> _loggedLocalThumbPaths = <String>{};

void _debugLogLocalFailureOnce(String path, String reason) {
  if (_loggedLocalThumbPaths.contains(path)) return;
  _loggedLocalThumbPaths.add(path);
  debugPrint(
    'CollectibleThumbImage: local shelf media unavailable — $reason — "$path"',
  );
}

/// Local file image for mobile/desktop/native embedding (not web).
///
/// Missing files and decode failures degrade to [CollectibleFigurePlaceholder]
/// without crashing. After failure, [Image.file] is not mounted again (stable
/// shelf, no decode/log spam on parent rebuilds).
Widget buildCollectibleLocalFileImage({
  required String filePath,
  required String name,
  required String seedKey,
  required bool isSecret,
  required bool compact,
  required BoxFit fit,
  required BorderRadius borderRadius,
}) {
  return _CollectibleLocalFileImage(
    filePath: filePath,
    name: name,
    seedKey: seedKey,
    isSecret: isSecret,
    compact: compact,
    fit: fit,
    borderRadius: borderRadius,
  );
}

class _CollectibleLocalFileImage extends StatefulWidget {
  const _CollectibleLocalFileImage({
    required this.filePath,
    required this.name,
    required this.seedKey,
    required this.isSecret,
    required this.compact,
    required this.fit,
    required this.borderRadius,
  });

  final String filePath;
  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  State<_CollectibleLocalFileImage> createState() =>
      _CollectibleLocalFileImageState();
}

class _CollectibleLocalFileImageState
    extends State<_CollectibleLocalFileImage> {
  /// After true, only placeholder is built (no [Image.file] retry on rebuild).
  bool _usePlaceholderOnly = false;

  @override
  void initState() {
    super.initState();
    _primeMissingFilePlaceholder();
  }

  @override
  void didUpdateWidget(covariant _CollectibleLocalFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      setState(() {
        _usePlaceholderOnly = false;
        try {
          if (!File(widget.filePath).existsSync()) {
            _debugLogLocalFailureOnce(widget.filePath, 'file missing');
            _usePlaceholderOnly = true;
          }
        } on Object catch (e) {
          _debugLogLocalFailureOnce(widget.filePath, 'exists check error: $e');
          _usePlaceholderOnly = true;
        }
      });
    }
  }

  void _primeMissingFilePlaceholder() {
    try {
      if (!File(widget.filePath).existsSync()) {
        _debugLogLocalFailureOnce(widget.filePath, 'file missing');
        _usePlaceholderOnly = true;
      }
    } on Object catch (e) {
      _debugLogLocalFailureOnce(widget.filePath, 'exists check error: $e');
      _usePlaceholderOnly = true;
    }
  }

  void _onDecodeFailed(Object error) {
    _debugLogLocalFailureOnce(widget.filePath, '$error');
    if (mounted) {
      setState(() => _usePlaceholderOnly = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_usePlaceholderOnly) {
      return CollectibleFigurePlaceholder(
        name: widget.name,
        seedKey: widget.seedKey,
        isSecret: widget.isSecret,
        compact: widget.compact,
      );
    }

    CatalogAspectImage.assertAspectPreservingFit(widget.fit);
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: CatalogAspectImage.coverFile(
        file: File(widget.filePath),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _onDecodeFailed(error),
          );
          return CollectibleFigurePlaceholder(
            name: widget.name,
            seedKey: widget.seedKey,
            isSecret: widget.isSecret,
            compact: widget.compact,
          );
        },
      ),
    );
  }
}
