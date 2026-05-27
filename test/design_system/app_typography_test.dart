import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: build a [ThemeData] context and run [callback] with its
/// [TextTheme] and [ColorScheme] without requiring a full widget pump.
T _withTheme<T>(T Function(TextTheme, ColorScheme) callback) {
  final theme = ThemeData.light(useMaterial3: true);
  return callback(theme.textTheme, theme.colorScheme);
}

void main() {
  group('AppTypography — non-null smoke', () {
    // Every role must return a valid TextStyle. If a role throws or returns
    // null it means a TextTheme role was accessed on a null slot.
    final roles = <String, TextStyle Function(TextTheme, ColorScheme)>{
      'tabTitle': AppTypography.tabTitle,
      'screenTitle': AppTypography.screenTitle,
      'sectionTitle': AppTypography.sectionTitle,
      'sectionLabel': AppTypography.sectionLabel,
      'cardTitle': AppTypography.cardTitle,
      'cardMeta': AppTypography.cardMeta,
      'deckText': AppTypography.deckText,
      'supportive': AppTypography.supportive,
      'insightsTotals': AppTypography.insightsTotals,
      'insightsFlavor': AppTypography.insightsFlavor,
      'insightsCaption': AppTypography.insightsCaption,
    };

    for (final entry in roles.entries) {
      test('${entry.key} returns a non-null TextStyle', () {
        final style = _withTheme(entry.value);
        expect(style, isA<TextStyle>());
      });
    }
  });

  group('AppTypography — weight hierarchy', () {
    test('tabTitle is w700', () {
      final style = _withTheme(AppTypography.tabTitle);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('screenTitle is w700', () {
      final style = _withTheme(AppTypography.screenTitle);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('sectionTitle is w600', () {
      final style = _withTheme(AppTypography.sectionTitle);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('sectionLabel is w600', () {
      final style = _withTheme(AppTypography.sectionLabel);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('cardTitle is w600', () {
      final style = _withTheme(AppTypography.cardTitle);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('insightsTotals is w700', () {
      final style = _withTheme(AppTypography.insightsTotals);
      expect(style.fontWeight, FontWeight.w700);
    });
  });

  group('AppTypography — style delegates match CollectibleTypography', () {
    test('sectionTitle matches CollectibleTypography.shelfSeriesTitle weight', () {
      _withTheme((t, s) {
        final appStyle = AppTypography.sectionTitle(t, s);
        final ctStyle = CollectibleTypography.shelfSeriesTitle(t, s);
        expect(appStyle.fontWeight, ctStyle.fontWeight);
      });
    });

    test('screenTitle matches CollectibleTypography.editorialScreenTitle weight', () {
      _withTheme((t, s) {
        final appStyle = AppTypography.screenTitle(t, s);
        final ctStyle = CollectibleTypography.editorialScreenTitle(t, s);
        expect(appStyle.fontWeight, ctStyle.fontWeight);
      });
    });

    test('cardTitle matches CollectibleTypography.catalogSeriesRowTitle weight', () {
      _withTheme((t, s) {
        final appStyle = AppTypography.cardTitle(t, s);
        final ctStyle = CollectibleTypography.catalogSeriesRowTitle(t, s);
        expect(appStyle.fontWeight, ctStyle.fontWeight);
      });
    });
  });

  group('AppTypography — Insights-specific roles', () {
    test('insightsFlavor has italic fontStyle', () {
      final style = _withTheme(AppTypography.insightsFlavor);
      expect(style.fontStyle, FontStyle.italic);
    });

    test('insightsFlavor has a set height > 1.0', () {
      final style = _withTheme(AppTypography.insightsFlavor);
      expect(style.height, isNotNull);
      expect(style.height, greaterThan(1.0));
    });

    test('insightsTotals has negative letterSpacing for tight numerals', () {
      final style = _withTheme(AppTypography.insightsTotals);
      expect(style.letterSpacing, isNotNull);
      expect(style.letterSpacing, lessThan(0));
    });

    test('insightsCaption has positive letterSpacing', () {
      final style = _withTheme(AppTypography.insightsCaption);
      expect(style.letterSpacing, isNotNull);
      expect(style.letterSpacing, greaterThan(0));
    });
  });

  group('AppTypography — hierarchy ordering', () {
    // Sanity check: higher-hierarchy roles should not be smaller than lower ones.
    // We compare `fontSize` from the resolved TextStyle against the base TextTheme.
    test('tabTitle fontSize >= sectionTitle fontSize', () {
      _withTheme((t, s) {
        final tab = AppTypography.tabTitle(t, s);
        final section = AppTypography.sectionTitle(t, s);
        // Both inherit from TextTheme; fontSize may be null for inherited styles.
        // Only assert when both are resolved.
        final tabSize = tab.fontSize ?? t.titleLarge?.fontSize;
        final sectionSize = section.fontSize ?? t.titleMedium?.fontSize;
        if (tabSize != null && sectionSize != null) {
          expect(tabSize, greaterThanOrEqualTo(sectionSize));
        }
      });
    });

    test('sectionTitle fontSize >= cardTitle fontSize', () {
      _withTheme((t, s) {
        final section = AppTypography.sectionTitle(t, s);
        final card = AppTypography.cardTitle(t, s);
        final sectionSize = section.fontSize ?? t.titleMedium?.fontSize;
        final cardSize = card.fontSize ?? t.titleSmall?.fontSize;
        if (sectionSize != null && cardSize != null) {
          expect(sectionSize, greaterThanOrEqualTo(cardSize));
        }
      });
    });
  });
}
