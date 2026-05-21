import 'package:flutter/material.dart';

/// Subtle secret-figure card tint from catalog `rarityLabel` ratios (e.g. `1:72`).
abstract final class FigureSecretRarityStyle {
  static final RegExp _ratioPattern = RegExp(r'^(\d+)\s*:\s*(\d+)\s*$');

  static const Color _blue = Color(0xFF6B9FE8);
  static const Color _purple = Color(0xFF9B7FD4);
  static const Color _gold = Color(0xFFD4AF5A);

  /// Parses the denominator from strings like `1:72`; null when not a ratio label.
  static int? parseRatioDenominator(String? rarityLabel) {
    final raw = rarityLabel?.trim();
    if (raw == null || raw.isEmpty) return null;
    final match = _ratioPattern.firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(2)!);
  }

  /// Secret figures only; null for regular slots. Missing ratio label → blue (`1:72`) tier.
  static FigureSecretRarityLook? resolve({
    required bool isSecret,
    String? rarityLabel,
    required bool isDark,
  }) {
    if (!isSecret) return null;
    final denom = parseRatioDenominator(rarityLabel) ?? 72;
    final accent = denom <= 72
        ? _blue
        : denom <= 144
            ? _purple
            : _gold;
    return FigureSecretRarityLook(accent: accent, isDark: isDark);
  }
}

/// Resolved tint palette for one secret figure card.
final class FigureSecretRarityLook {
  const FigureSecretRarityLook({required this.accent, required this.isDark});

  final Color accent;
  final bool isDark;

  Color cardTint(Color base) =>
      Color.lerp(base, accent, isDark ? 0.14 : 0.2)!;

  Gradient cardGradient(Color base) {
    final soft = cardTint(base);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(soft, Colors.white, isDark ? 0.06 : 0.22)!,
        soft,
        Color.lerp(soft, accent, 0.12)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }

  List<BoxShadow> glowShadows() => [
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.14 : 0.12),
          blurRadius: 16,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
      ];

  Color subtleBorder() => accent.withValues(alpha: isDark ? 0.42 : 0.5);
}
