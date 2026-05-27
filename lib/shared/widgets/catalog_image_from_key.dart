import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/catalog_resolved_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Stable [Key] for catalog image widgets in lists — ties [State] to [imageKey].
Key catalogImageWidgetKey({
  required CatalogImageDisplayMode displayMode,
  required String imageKey,
  String? identity,
}) {
  final id = identity?.trim();
  final k = imageKey.trim();
  if (id != null && id.isNotEmpty) {
    return ValueKey<String>('catalog-img:$displayMode:$id:$k');
  }
  return ValueKey<String>('catalog-img:$displayMode:$k');
}

/// Ignores stale async resolve completions when [imageKey] changes quickly.
@visibleForTesting
class CatalogImageResolveCoordinator {
  int _generation = 0;

  int begin() => ++_generation;

  bool shouldApply(int generation) => generation == _generation;
}

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
    this.borderRadius,
    this.width,
    this.height,
  });

  final String imageKey;
  final String name;
  final String seedKey;
  final CatalogImageDisplayMode displayMode;
  final bool isSecret;
  final bool compact;
  final BorderRadius? borderRadius;
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
        : CatalogImageDisplayMode.figureThumb;
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
  final CatalogImageResolveCoordinator _resolveCoordinator =
      CatalogImageResolveCoordinator();

  String? _imageRef;
  bool _loading = true;

  CatalogImageDisplaySpec get _spec => CatalogImageDisplaySpec.forMode(
        widget.displayMode,
        imageRef: _imageRef ?? widget.imageKey,
      );

  @override
  void initState() {
    super.initState();
    _startResolve();
  }

  @override
  void didUpdateWidget(CatalogImageFromKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageKey != widget.imageKey ||
        oldWidget.displayMode != widget.displayMode) {
      _startResolve();
    }
  }

  bool get _isSeriesMode => switch (widget.displayMode) {
    CatalogImageDisplayMode.seriesCoverThumb ||
    CatalogImageDisplayMode.seriesCoverHero ||
    CatalogImageDisplayMode.marketCatalogThumb => true,
    _ => false,
  };

  void _startResolve() {
    final generation = _resolveCoordinator.begin();
    final key = widget.imageKey.trim();

    if (key.isEmpty) {
      if (!mounted) return;
      setState(() {
        _imageRef = null;
        _loading = false;
      });
      return;
    }

    // Drop stale art immediately so recycled list cells never flash the prior series.
    if (mounted) {
      setState(() {
        _loading = true;
        _imageRef = null;
      });
    }

    _resolve(generation: generation, imageKey: key);
  }

  Future<void> _resolve({
    required int generation,
    required String imageKey,
  }) async {
    final bundled = _isSeriesMode
        ? await CatalogImageResolver.resolveSeriesAsset(imageKey)
        : await CatalogImageResolver.resolveFigureAsset(imageKey);

    if (!_resolveCoordinator.shouldApply(generation) || !mounted) return;

    if (bundled != null && bundled.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          'CatalogImageFromKey: imageKey="$imageKey" provider=bundled_asset '
          'path=$bundled',
        );
      }
      setState(() {
        _imageRef = bundled;
        _loading = false;
      });
      return;
    }

    String? ref;
    if (CatalogImageResolver.storageFallbackEnabled) {
      ref = _isSeriesMode
          ? await CatalogImageResolver.resolveSeriesStorageRef(imageKey)
          : await CatalogImageResolver.resolveFigureStorageRef(imageKey);
    }

    if (!_resolveCoordinator.shouldApply(generation) || !mounted) return;

    if (kDebugMode) {
      final provider = ref == null || ref.isEmpty
          ? 'placeholder'
          : (ref.startsWith('assets/') ? 'bundled_asset' : 'network_url');
      debugPrint(
        'CatalogImageFromKey: imageKey="$imageKey" provider=$provider '
        'storageFallback=${CatalogImageResolver.storageFallbackEnabled}',
      );
    }

    setState(() {
      _imageRef = ref;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ??
        CatalogImageDisplaySpec.borderRadiusFor(widget.displayMode);

    if (_loading) {
      return AppImageShimmer(borderRadius: radius);
    }
    if (_imageRef == null || _imageRef!.isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CollectibleFigurePlaceholder(
          name: widget.name,
          seedKey: widget.seedKey,
          isSecret: widget.isSecret,
          compact: widget.compact,
        ),
      );
    }
    return CatalogResolvedImage(
      key: ValueKey<String>(
        'catalog-resolved:${widget.imageKey.trim()}:$_imageRef',
      ),
      imageRef: _imageRef!,
      spec: _spec,
      name: widget.name,
      seedKey: widget.seedKey,
      isSecret: widget.isSecret,
      compact: widget.compact,
      borderRadius: radius,
      width: widget.width,
      height: widget.height,
      immersiveGalleryStage:
          widget.displayMode == CatalogImageDisplayMode.figureGallery,
    );
  }
}
