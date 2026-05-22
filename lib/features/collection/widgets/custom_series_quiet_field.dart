import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:flutter/material.dart';

/// Soft filled fields for custom series surfaces ([AppRadii.field] only).
InputDecoration quietCustomSeriesField(
  ColorScheme scheme, {
  required String hintText,
}) {
  final hintColor = scheme.onSurfaceVariant.withValues(alpha: 0.42);
  final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.2);
  final idleBorder = scheme.outlineVariant.withValues(alpha: 0.16);

  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w400),
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: BorderSide(color: idleBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: BorderSide(color: idleBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: BorderSide(
        color: scheme.primary.withValues(alpha: 0.32),
        width: 1,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
    ),
  );
}
