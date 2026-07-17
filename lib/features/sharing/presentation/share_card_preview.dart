import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/features/sharing/application/share_card_file_store.dart';
import 'package:blindbox_app/features/sharing/application/share_card_native_share.dart';
import 'package:blindbox_app/features/sharing/application/share_card_renderer.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';

Future<void> showShareCardPreview({
  required BuildContext context,
  required Widget card,
  required String basename,
  required String loadingLabel,
  required String previewTitle,
  ShareCardRenderer renderer = const ShareCardRenderer(),
  ShareCardFileStore fileStore = const ShareCardFileStore(),
  ShareCardNativeShare? nativeShare,
}) async {
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = Overlay.of(context, rootOverlay: true);
  final key = GlobalKey();
  final entry = _captureOverlayEntry(context, key, card);
  final share = nativeShare ?? ShareCardNativeShare();
  var entryInserted = false;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _ShareCardPreparingDialog(label: loadingLabel),
    ),
  );

  File? png;
  try {
    await fileStore.cleanupOldTemporaryPngs();
    overlay.insert(entry);
    entryInserted = true;

    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await WidgetsBinding.instance.endOfFrame;

    final bytes = await renderer.capturePng(key);
    png = await fileStore.writeTemporaryPng(bytes: bytes, basename: basename);
  } catch (_) {
    if (navigator.canPop()) navigator.pop();
    if (entryInserted) entry.remove();
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not prepare this Shelfy card.')),
    );
    return;
  }

  if (entryInserted) entry.remove();
  if (navigator.canPop()) navigator.pop();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (_) => _ShareCardPreviewSheet(
      file: png!,
      fileName: '$basename.png',
      nativeShare: share,
    ),
  );
}

OverlayEntry _captureOverlayEntry(
  BuildContext context,
  GlobalKey key,
  Widget card,
) {
  final inherited = InheritedTheme.captureAll(
    context,
    MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: kShelfyShareCardLogicalSize,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
      ),
      child: Directionality(
        textDirection: Directionality.of(context),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: ShareCardCaptureBoundary(captureKey: key, child: card),
          ),
        ),
      ),
    ),
  );

  return OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      top: 0,
      width: kShelfyShareCardLogicalSize.width,
      height: kShelfyShareCardLogicalSize.height,
      child: IgnorePointer(child: Opacity(opacity: 0.01, child: inherited)),
    ),
  );
}

class _ShareCardPreparingDialog extends StatelessWidget {
  const _ShareCardPreparingDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareCardPreviewSheet extends StatefulWidget {
  const _ShareCardPreviewSheet({
    required this.file,
    required this.fileName,
    required this.nativeShare,
  });

  final File file;
  final String fileName;
  final ShareCardNativeShare nativeShare;

  @override
  State<_ShareCardPreviewSheet> createState() => _ShareCardPreviewSheetState();
}

@visibleForTesting
double shareCardPreviewTopChromeHeight() =>
    _ShareCardPreviewLayout.topChromeHeight;

@visibleForTesting
bool shareCardPreviewShowsCloseButton() => false;

class _ShareCardPreviewSheetState extends State<_ShareCardPreviewSheet> {
  Offset _pointer = Offset.zero;
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await widget.nativeShare.sharePng(
        file: widget.file,
        fileName: widget.fileName,
        sharePositionOrigin: _shareOrigin(),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = calculateShareCardPreviewMetrics(
      viewportSize: MediaQuery.sizeOf(context),
      viewPadding: MediaQuery.viewPaddingOf(context),
    );
    final dx = (_pointer.dx - 0.5) * 3;
    final dy = (_pointer.dy - 0.5) * 3;
    final topChromeHeight = shareCardPreviewTopChromeHeight();
    const handleTop = 6.0;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _ShareCardPreviewLayout.outerHorizontalPadding,
            metrics.topSafeSpacing,
            _ShareCardPreviewLayout.outerHorizontalPadding,
            _ShareCardPreviewLayout.outerBottomPadding,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: Transform.scale(
                  scale: 0.97 + value * 0.03,
                  child: child,
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: metrics.sheetMaxHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEDE6F6), Color(0xFFF7F0FA)],
                  ),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 38,
                      spreadRadius: -14,
                      offset: const Offset(0, 24),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(-1, -3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _ShareCardPreviewLayout.innerHorizontalPadding,
                    _ShareCardPreviewLayout.innerTopPadding,
                    _ShareCardPreviewLayout.innerHorizontalPadding,
                    metrics.innerBottomPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: topChromeHeight,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Positioned(
                              top: handleTop,
                              child: const CollectibleSheetDragHandle(),
                            ),
                          ],
                        ),
                      ),
                      MouseRegion(
                        onHover: (event) {
                          final box = context.findRenderObject();
                          if (box is! RenderBox || !box.hasSize) return;
                          final local = box.globalToLocal(event.position);
                          setState(() {
                            _pointer = Offset(
                              (local.dx / box.size.width).clamp(0, 1),
                              (local.dy / box.size.height).clamp(0, 1),
                            );
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.translationValues(dx, dy, 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFEDE6F6), Color(0xFFF7F0FA)],
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: Image.file(
                                widget.file,
                                width: metrics.cardSize.width,
                                height: metrics.cardSize.height,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: _ShareCardPreviewLayout.cardButtonGap,
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: _ShareCardPreviewLayout.shareButtonHeight,
                        child: FilledButton.icon(
                          onPressed: _sharing ? null : _share,
                          style: FilledButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Color.lerp(
                              scheme.primary,
                              scheme.surfaceContainerHighest,
                              0.18,
                            ),
                            foregroundColor: scheme.onPrimary.withValues(
                              alpha: 0.9,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _sharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.ios_share_rounded),
                          label: Text(
                            _sharing ? 'Opening share sheet...' : 'Share',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class ShareCardPreviewMetrics {
  const ShareCardPreviewMetrics({
    required this.cardSize,
    required this.sheetMaxHeight,
    required this.topSafeSpacing,
    required this.innerBottomPadding,
  });

  final Size cardSize;
  final double sheetMaxHeight;
  final double topSafeSpacing;
  final double innerBottomPadding;

  double get contentHeight =>
      _ShareCardPreviewLayout.innerTopPadding +
      _ShareCardPreviewLayout.topChromeHeight +
      cardSize.height +
      _ShareCardPreviewLayout.cardButtonGap +
      _ShareCardPreviewLayout.shareButtonHeight +
      innerBottomPadding;

  double get occupiedViewportHeight =>
      topSafeSpacing +
      contentHeight +
      _ShareCardPreviewLayout.outerBottomPadding;
}

class _ShareCardPreviewLayout {
  static final double cardAspectRatio =
      kShelfyShareCardLogicalSize.width / kShelfyShareCardLogicalSize.height;
  static const double minTopSpacing = 12;
  static const double topSafeGap = 8;
  static const double outerHorizontalPadding = 10;
  static const double outerBottomPadding = 6;
  static const double innerHorizontalPadding = 8;
  static const double innerTopPadding = 6;
  static const double innerBottomPadding = 8;
  static const double minBottomSpacing = 18;
  static const double topChromeHeight = 30;
  static const double cardButtonGap = 14;
  static const double shareButtonHeight = 46;
}

@visibleForTesting
ShareCardPreviewMetrics calculateShareCardPreviewMetrics({
  required Size viewportSize,
  required EdgeInsets viewPadding,
}) {
  final topSafeSpacing = math.max(
    _ShareCardPreviewLayout.minTopSpacing,
    viewPadding.top + _ShareCardPreviewLayout.topSafeGap,
  );
  final innerBottomPadding = math.max(
    _ShareCardPreviewLayout.innerBottomPadding + viewPadding.bottom,
    _ShareCardPreviewLayout.minBottomSpacing,
  );
  final sheetMaxHeight = math.max(
    0.0,
    viewportSize.height -
        topSafeSpacing -
        _ShareCardPreviewLayout.outerBottomPadding,
  );
  final availableWidth = math.max(
    0.0,
    viewportSize.width -
        _ShareCardPreviewLayout.outerHorizontalPadding * 2 -
        _ShareCardPreviewLayout.innerHorizontalPadding * 2,
  );
  final reservedVerticalSpace =
      _ShareCardPreviewLayout.innerTopPadding +
      _ShareCardPreviewLayout.topChromeHeight +
      _ShareCardPreviewLayout.cardButtonGap +
      _ShareCardPreviewLayout.shareButtonHeight +
      innerBottomPadding;
  final maxCardHeight = math.max(0.0, sheetMaxHeight - reservedVerticalSpace);
  final heightLimitedWidth =
      maxCardHeight * _ShareCardPreviewLayout.cardAspectRatio;
  final cardWidth = math.min(availableWidth, heightLimitedWidth);
  final cardHeight = _ShareCardPreviewLayout.cardAspectRatio == 0
      ? 0.0
      : cardWidth / _ShareCardPreviewLayout.cardAspectRatio;

  return ShareCardPreviewMetrics(
    cardSize: Size(cardWidth, cardHeight),
    sheetMaxHeight: sheetMaxHeight,
    topSafeSpacing: topSafeSpacing,
    innerBottomPadding: innerBottomPadding,
  );
}
