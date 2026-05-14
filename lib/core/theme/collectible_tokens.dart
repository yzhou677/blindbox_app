import 'package:flutter/material.dart';

/// Depth and supportive-copy tokens — spacing lives in [FeedRhythm].
@immutable
class CollectibleTokens extends ThemeExtension<CollectibleTokens> {
  const CollectibleTokens({
    required this.supportiveBodyAlpha,
    required this.supportiveMetaAlpha,
    required this.supportiveBodyHeight,
    required this.shellShadowLightAlpha,
    required this.shellShadowDarkAlpha,
    required this.shellShadowAccentMix,
    required this.shellShadowBlur,
    required this.shellShadowDy,
    required this.shellShadowSpread,
  });

  final double supportiveBodyAlpha;
  final double supportiveMetaAlpha;
  final double supportiveBodyHeight;
  final double shellShadowLightAlpha;
  final double shellShadowDarkAlpha;
  final double shellShadowAccentMix;
  final double shellShadowBlur;
  final double shellShadowDy;
  final double shellShadowSpread;

  static CollectibleTokens of(BuildContext context) {
    return Theme.of(context).extension<CollectibleTokens>()!;
  }

  TextStyle supportiveBody(TextTheme textTheme, ColorScheme scheme) {
    return textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: supportiveBodyAlpha),
      height: supportiveBodyHeight,
      letterSpacing: 0.04,
      fontWeight: FontWeight.w400,
    );
  }

  TextStyle supportiveMeta(TextTheme textTheme, ColorScheme scheme) {
    return textTheme.labelMedium!.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: supportiveMetaAlpha),
      height: 1.45,
      letterSpacing: 0.04,
      fontWeight: FontWeight.w400,
    );
  }

  static CollectibleTokens forBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return CollectibleTokens(
      supportiveBodyAlpha: isLight ? 0.68 : 0.72,
      supportiveMetaAlpha: isLight ? 0.5 : 0.58,
      supportiveBodyHeight: 1.5,
      shellShadowLightAlpha: isLight ? 0.12 : 0.24,
      shellShadowDarkAlpha: isLight ? 0.1 : 0.24,
      shellShadowAccentMix: isLight ? 0.11 : 0.16,
      shellShadowBlur: isLight ? 32 : 36,
      shellShadowDy: isLight ? 11 : 10,
      shellShadowSpread: -4,
    );
  }

  @override
  CollectibleTokens copyWith({
    double? supportiveBodyAlpha,
    double? supportiveMetaAlpha,
    double? supportiveBodyHeight,
    double? shellShadowLightAlpha,
    double? shellShadowDarkAlpha,
    double? shellShadowAccentMix,
    double? shellShadowBlur,
    double? shellShadowDy,
    double? shellShadowSpread,
  }) {
    return CollectibleTokens(
      supportiveBodyAlpha: supportiveBodyAlpha ?? this.supportiveBodyAlpha,
      supportiveMetaAlpha: supportiveMetaAlpha ?? this.supportiveMetaAlpha,
      supportiveBodyHeight: supportiveBodyHeight ?? this.supportiveBodyHeight,
      shellShadowLightAlpha: shellShadowLightAlpha ?? this.shellShadowLightAlpha,
      shellShadowDarkAlpha: shellShadowDarkAlpha ?? this.shellShadowDarkAlpha,
      shellShadowAccentMix: shellShadowAccentMix ?? this.shellShadowAccentMix,
      shellShadowBlur: shellShadowBlur ?? this.shellShadowBlur,
      shellShadowDy: shellShadowDy ?? this.shellShadowDy,
      shellShadowSpread: shellShadowSpread ?? this.shellShadowSpread,
    );
  }

  @override
  ThemeExtension<CollectibleTokens> lerp(ThemeExtension<CollectibleTokens>? other, double t) {
    if (other is! CollectibleTokens) return this;
    return CollectibleTokens(
      supportiveBodyAlpha: _d(supportiveBodyAlpha, other.supportiveBodyAlpha, t),
      supportiveMetaAlpha: _d(supportiveMetaAlpha, other.supportiveMetaAlpha, t),
      supportiveBodyHeight: _d(supportiveBodyHeight, other.supportiveBodyHeight, t),
      shellShadowLightAlpha: _d(shellShadowLightAlpha, other.shellShadowLightAlpha, t),
      shellShadowDarkAlpha: _d(shellShadowDarkAlpha, other.shellShadowDarkAlpha, t),
      shellShadowAccentMix: _d(shellShadowAccentMix, other.shellShadowAccentMix, t),
      shellShadowBlur: _d(shellShadowBlur, other.shellShadowBlur, t),
      shellShadowDy: _d(shellShadowDy, other.shellShadowDy, t),
      shellShadowSpread: _d(shellShadowSpread, other.shellShadowSpread, t),
    );
  }

  static double _d(double a, double b, double t) => a + (b - a) * t;
}
