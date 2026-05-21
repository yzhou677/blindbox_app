import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Resolves a catalog [imageKey] to bundled asset or Firebase Storage URL for display.
class CatalogImageFromKey extends StatefulWidget {
  const CatalogImageFromKey({
    super.key,
    required this.imageKey,
    required this.name,
    required this.seedKey,
    this.series = false,
    this.isSecret = false,
    this.compact = false,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final String imageKey;
  final String name;
  final String seedKey;
  final bool series;
  final bool isSecret;
  final bool compact;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  State<CatalogImageFromKey> createState() => _CatalogImageFromKeyState();
}

class _CatalogImageFromKeyState extends State<CatalogImageFromKey> {
  String? _imageRef;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CatalogImageFromKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageKey != widget.imageKey || oldWidget.series != widget.series) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _imageRef = null;
    });
    final ref = widget.series
        ? await CatalogImageResolver.resolveSeriesDisplayRef(widget.imageKey)
        : await CatalogImageResolver.resolveFigureDisplayRef(widget.imageKey);
    if (!mounted) return;
    setState(() {
      _imageRef = ref;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_imageRef == null || _imageRef!.isEmpty) {
      return CollectibleFigurePlaceholder(
        name: widget.name,
        seedKey: widget.seedKey,
        isSecret: widget.isSecret,
        compact: widget.compact,
      );
    }
    return CollectibleThumbImage(
      imageRef: _imageRef,
      name: widget.name,
      seedKey: widget.seedKey,
      isSecret: widget.isSecret,
      compact: widget.compact,
      fit: widget.fit,
      borderRadius: widget.borderRadius,
    );
  }
}
