import 'package:blindbox_app/features/collection/presentation/figure_secret_rarity_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseRatioDenominator accepts catalog rarityLabel shapes', () {
    expect(FigureSecretRarityStyle.parseRatioDenominator('1:72'), 72);
    expect(FigureSecretRarityStyle.parseRatioDenominator(' 1 : 144 '), 144);
    expect(FigureSecretRarityStyle.parseRatioDenominator('Secret'), isNull);
  });

  test('resolve returns null for non-secret figures', () {
    expect(
      FigureSecretRarityStyle.resolve(isSecret: false, rarityLabel: '1:72', isDark: false),
      isNull,
    );
  });

  test('resolve tiers secret figures by denominator', () {
    final blue = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:72',
      isDark: false,
    )!;
    final purple = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:144',
      isDark: false,
    )!;
    final gold = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:288',
      isDark: false,
    )!;
    expect(blue.accent, isNot(equals(purple.accent)));
    expect(purple.accent, isNot(equals(gold.accent)));
  });

  test('resolve uses blue tier when secret has no ratio label', () {
    final fallback = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: null,
      isDark: false,
    )!;
    final blue = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:72',
      isDark: false,
    )!;
    expect(fallback.accent, equals(blue.accent));
  });

  test('tier boundaries at 72, 144, and 145 denominators', () {
    final at72 = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:72',
      isDark: false,
    )!;
    final at144 = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:144',
      isDark: false,
    )!;
    final at145 = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:145',
      isDark: false,
    )!;
    expect(at72.accent, isNot(equals(at144.accent)));
    expect(at144.accent, isNot(equals(at145.accent)));
    expect(at145.accent, equals(
      FigureSecretRarityStyle.resolve(
        isSecret: true,
        rarityLabel: '1:288',
        isDark: false,
      )!.accent,
    ));
  });

  test('cardTint and glowShadows are non-destructive', () {
    final look = FigureSecretRarityStyle.resolve(
      isSecret: true,
      rarityLabel: '1:144',
      isDark: false,
    )!;
    final base = const Color(0xFFF5F5F5);
    expect(look.cardTint(base), isNot(equals(base)));
    expect(look.glowShadows(), isNotEmpty);
  });
}
