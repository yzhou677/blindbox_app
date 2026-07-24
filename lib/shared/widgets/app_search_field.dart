import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/widgets/camera_capture_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified luxury search field — Market, Discover, catalog browse, Add Series.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
    this.suffixIcon,
    this.onImageSelected,
    this.photoAcquirer,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      10,
    ),
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final TextInputAction textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<CatalogPhotoSelection>? onImageSelected;
  final CatalogPhotoAcquirer? photoAcquirer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final contentOpacity = enabled ? 1.0 : 0.44;
    final hintOpacity = enabled ? 0.72 : 0.34;
    final iconOpacity = enabled ? 0.75 : 0.3;

    final field = IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: contentOpacity,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly || !enabled,
          enabled: enabled,
          showCursor: enabled,
          onTap: enabled ? onTap : null,
          onChanged: enabled ? onChanged : null,
          onSubmitted: enabled && onSubmitted != null
              ? (_) => onSubmitted!()
              : null,
          autofocus: enabled && autofocus,
          textInputAction: textInputAction,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: hintOpacity),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 22,
              color: scheme.onSurfaceVariant.withValues(alpha: iconOpacity),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: _buildSuffix(context, scheme),
            suffixIconConstraints: onImageSelected == null
                ? null
                : const BoxConstraints(minHeight: 48),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: AppRadii.fieldRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.fieldRadius,
              borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.fieldRadius,
              borderSide: BorderSide(
                color: scheme.primary.withValues(alpha: 0.38),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              14,
              AppSpacing.md,
              14,
            ),
            isDense: true,
          ),
        ),
      ),
    );

    return Padding(padding: padding, child: field);
  }

  Widget? _buildSuffix(BuildContext context, ColorScheme scheme) {
    if (onImageSelected == null) return suffixIcon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?suffixIcon,
        IconButton(
          key: const Key('catalog-photo-action'),
          tooltip: 'Scan a collectible',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(6),
          icon: DecoratedBox(
            key: const Key('catalog-photo-action-container'),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.62),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                Icons.photo_camera_outlined,
                key: const Key('catalog-photo-action-icon'),
                size: 20,
                color: scheme.onTertiaryContainer.withValues(alpha: 0.88),
              ),
            ),
          ),
          onPressed: enabled ? () => _choosePhoto(context) : null,
        ),
      ],
    );
  }

  Future<void> _choosePhoto(BuildContext context) async {
    // Opening the source picker must not transfer focus away from (and then
    // restore focus to) the catalog search field. On a nested Collection
    // sheet that focus round-trip can reopen the keyboard after dismissal and
    // temporarily relayout the Collection viewport behind the modal.
    FocusManager.instance.primaryFocus?.unfocus();
    final source = await _showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    if (source == CatalogPhotoSource.camera) {
      final shouldOpenCamera = await showCameraCaptureGuidance(context);
      if (!shouldOpenCamera || !context.mounted) return;
    }
    try {
      final result = await (photoAcquirer ?? ImagePickerCatalogPhotoAcquirer())
          .acquire(source);
      if (result != null && context.mounted) {
        onImageSelected?.call(result);
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        _showPhotoError(context, _platformErrorMessage(error));
      }
    } on FormatException catch (error) {
      if (context.mounted) _showPhotoError(context, error.message);
    } catch (_) {
      if (context.mounted) {
        _showPhotoError(
          context,
          'Could not open that image. Please try again.',
        );
      }
    }
  }

  Future<CatalogPhotoSource?> _showPhotoSourceSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return showModalBottomSheet<CatalogPhotoSource>(
      context: context,
      useRootNavigator: false,
      requestFocus: false,
      isScrollControlled: false,
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
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return _PhotoSourceSheet(
          scheme: scheme,
          bottomInset: bottomInset,
          onCamera: () =>
              Navigator.pop(sheetContext, CatalogPhotoSource.camera),
          onGallery: () =>
              Navigator.pop(sheetContext, CatalogPhotoSource.gallery),
          onCancel: () => Navigator.pop(sheetContext),
        );
      },
    );
  }

  static String _platformErrorMessage(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('permission') || code.contains('denied')) {
      return 'Photo access was denied. You can allow access in Settings.';
    }
    if (code.contains('camera')) return 'The camera is unavailable right now.';
    return 'Could not open that image. Please try again.';
  }

  static void _showPhotoError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet({
    required this.scheme,
    required this.bottomInset,
    required this.onCamera,
    required this.onGallery,
    required this.onCancel,
  });

  final ColorScheme scheme;
  final double bottomInset;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('photo-source-sheet'),
      padding: EdgeInsets.zero,
      child: Material(
        color: scheme.surfaceContainerLow,
        elevation: 10,
        shadowColor: scheme.shadow.withValues(alpha: 0.22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 6, 10, 6 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const Key('photo-source-drag-region'),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              _PhotoSourceRow(
                icon: Icons.photo_camera_outlined,
                label: 'Take Photo',
                onTap: onCamera,
              ),
              const SizedBox(height: 2),
              _PhotoSourceRow(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Photos',
                onTap: onGallery,
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('photo-source-cancel'),
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.72),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceRow extends StatelessWidget {
  const _PhotoSourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: Icon(icon, size: 23, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
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
