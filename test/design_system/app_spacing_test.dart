import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing primitive scale', () {
    test('values are positive and in ascending order', () {
      expect(AppSpacing.xs, greaterThan(0));
      expect(AppSpacing.sm, greaterThan(AppSpacing.xs));
      expect(AppSpacing.md, greaterThan(AppSpacing.sm));
      expect(AppSpacing.lg, greaterThan(AppSpacing.md));
      expect(AppSpacing.xl, greaterThan(AppSpacing.lg));
      expect(AppSpacing.xxl, greaterThan(AppSpacing.xl));
    });

    test('primitive values are unchanged from original scale', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 20);
      expect(AppSpacing.xxl, 24);
    });
  });

  group('AppSpacing semantic aliases', () {
    test('pageHorizontal equals xl (20)', () {
      expect(AppSpacing.pageHorizontal, AppSpacing.xl);
      expect(AppSpacing.pageHorizontal, 20);
    });

    test('pageHorizontalCompact equals lg (16)', () {
      expect(AppSpacing.pageHorizontalCompact, AppSpacing.lg);
      expect(AppSpacing.pageHorizontalCompact, 16);
    });

    test('emptyStateHorizontal is wider than pageHorizontal', () {
      expect(AppSpacing.emptyStateHorizontal, greaterThan(AppSpacing.pageHorizontal));
      expect(AppSpacing.emptyStateHorizontal, 28);
    });

    test('belowTabAppBar matches FeedRhythm.belowMainTabAppBar', () {
      expect(AppSpacing.belowTabAppBar, FeedRhythm.belowMainTabAppBar);
    });

    test('belowTabAppBarToSearch matches FeedRhythm.headerToSearchField', () {
      expect(AppSpacing.belowTabAppBarToSearch, FeedRhythm.headerToSearchField);
    });
  });

  group('AppSpacing card padding EdgeInsets', () {
    test('cardPadding horizontal equals 2 × pageHorizontal', () {
      expect(
        AppSpacing.cardPadding.horizontal,
        AppSpacing.pageHorizontal * 2,
      );
    });

    test('cardPadding vertical equals 2 × md', () {
      expect(AppSpacing.cardPadding.vertical, AppSpacing.md * 2);
    });

    test('cardPaddingCompact horizontal equals 2 × pageHorizontalCompact', () {
      expect(
        AppSpacing.cardPaddingCompact.horizontal,
        AppSpacing.pageHorizontalCompact * 2,
      );
    });

    test('cardPaddingCompact vertical equals 2 × md', () {
      expect(AppSpacing.cardPaddingCompact.vertical, AppSpacing.md * 2);
    });

    test('cardPadding is wider than cardPaddingCompact', () {
      expect(
        AppSpacing.cardPadding.horizontal,
        greaterThan(AppSpacing.cardPaddingCompact.horizontal),
      );
    });

    test('cardPadding has symmetric left and right', () {
      expect(AppSpacing.cardPadding.left, AppSpacing.cardPadding.right);
    });

    test('cardPadding has symmetric top and bottom', () {
      expect(AppSpacing.cardPadding.top, AppSpacing.cardPadding.bottom);
    });

    test('cardPadding is a const EdgeInsets (not null)', () {
      const padding = AppSpacing.cardPadding;
      expect(padding, isA<EdgeInsets>());
    });
  });

  group('AppSpacing regression guard', () {
    // These tests prevent silent regressions when values are changed.
    test('no AppSpacing value is zero or negative', () {
      for (final v in [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.pageHorizontal,
        AppSpacing.pageHorizontalCompact,
        AppSpacing.emptyStateHorizontal,
        AppSpacing.belowTabAppBar,
        AppSpacing.belowTabAppBarToSearch,
      ]) {
        expect(v, greaterThan(0), reason: 'All spacing values must be positive');
      }
    });

    test('page gutter is narrower than emptyStateHorizontal', () {
      // Centred empty-state copy is always narrower than full-bleed page content.
      expect(
        AppSpacing.emptyStateHorizontal,
        greaterThan(AppSpacing.pageHorizontal),
      );
    });
  });
}
