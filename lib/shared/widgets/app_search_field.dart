import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

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
            suffixIcon: suffixIcon,
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
}
