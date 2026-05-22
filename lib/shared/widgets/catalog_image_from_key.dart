import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_resolved_image.dart';
import 'package:flutter/material.dart';

/// Resolves a catalog [imageKey] then renders via [CatalogImageDisplaySpec].
class CatalogImageFromKey extends StatefulWidget {
  const CatalogImageFromKey({
    super.key,
    required this.imageKey,
    required this.name,
    required this.seedKey,
    required this.displayMode,
    this.isSecret = false,
    this.compact = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.width,
    this.height,
  });

  final String imageKey;
  final String name;
  final String seedKey;
  final CatalogImageDisplayMode displayMode;
  final bool isSecret;
  final bool compact;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;

  /// Series vs figure + compact hint (legacy call sites).
  factory CatalogImageFromKey.legacy({
    Key? key,
    required String imageKey,
    required String name,
    required String seedKey,
    bool series = false,
    bool isSecret = false,
    bool compact = false,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
    double? width,
    double? height,
  }) {
    final mode = series
        ? (compact
            ? CatalogImageDisplayMode.seriesCoverThumb
            : CatalogImageDisplayMode.seriesCoverHero)
        : (compact
            ? CatalogImageDisplayMode.figureThumb
            : CatalogImageDisplayMode.figureThumb);
    return CatalogImageFromKey(
      key: key,
      imageKey: imageKey,
      name: name,
      seedKey: seedKey,
      displayMode: mode,
      isSecret: isSecret,
      compact: compact,
      borderRadius: borderRadius,
      width: width,
      height: height,
    );
  }

  @override
  State<CatalogImageFromKey> createState() => _CatalogImageFromKeyState();
}

class _CatalogImageFromKeyState extends State<CatalogImageFromKey> {
  String? _imageRef;
  bool _loading = true;

  CatalogImageDisplaySpec get _spec => CatalogImageDisplaySpec.forMode(widget.displayMode);

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CatalogImageFromKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageKey != widget.imageKey ||
        oldWidget.displayMode != widget.displayMode) {
      _resolve();
    }
  }

  bool get _isSeriesMode => switch (widget.displayMode) {
        CatalogImageDisplayMode.seriesCoverThumb ||
        CatalogImageDisplayMode.seriesCoverHero ||
        CatalogImageDisplayMode.marketCatalogThumb => true,
        _ => false,
      };

  Future<void> _resolve() async {
    final key = widget.imageKey.trim();
    if (key.isEmpty) {
      if (!mounted) return;
      setState(() {
        _imageRef = null;
        _loading = false;
      });
      return;
    }

    // Bundled assets: instant paint without blocking on Storage.
    final bundled = _isSeriesMode
        ? await CatalogImageResolver.resolveSeriesAsset(key)
        : await CatalogImageResolver.resolveFigureAsset(key);
    if (bundled != null && bundled.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _imageRef = bundled;
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _imageRef = null;
    });

    final ref = _isSeriesMode
        ? await CatalogImageResolver.resolveSeriesDisplayRef(key)
        : await CatalogImageResolver.resolveFigureDisplayRef(key);
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
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: CollectibleFigurePlaceholder(
          name: widget.name,
          seedKey: widget.seedKey,
          isSecret: widget.isSecret,
          compact: widget.compact,
        ),
      );
    }
    return CatalogResolvedImage(
      imageRef: _imageRef!,
      spec: _spec,
      name: widget.name,
      seedKey: widget.seedKey,
      isSecret: widget.isSecret,
      compact: widget.compact,
      borderRadius: widget.borderRadius,
      width: widget.width,
      height: widget.height,
    );
  }
}
