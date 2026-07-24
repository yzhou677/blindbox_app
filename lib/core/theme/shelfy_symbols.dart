import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Shelfy Material Symbols Rounded defaults — call once at app start.
///
/// Canonical in-app chrome: Rounded geometry, outline fill (0), regular weight.
/// Large empty-state icons may override [opticalSize] / [weight] locally.
///
/// Prefer [AppIconSizes] for glyph `size` — keep weight / opsz on this class.
abstract final class ShelfySymbols {
  ShelfySymbols._();

  static const double weight = 400;
  static const double grade = 0;
  static const double opticalSize = 24;
  static const double fillOutline = 0;
  static const double fillSolid = 1;

  /// Empty-state hero icons (e.g. Wishlist heart) — thinner, larger optical size.
  static const double emptyStateWeight = 250;
  static const double emptyStateOpticalSize = 48;

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    MaterialSymbolsBase.setRoundedVariationDefaults(
      fill: fillOutline,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
    );
  }
}

/// Optical glyph size ladder (dp). Prefer these over one-off `size:` literals.
abstract final class AppIconSizes {
  AppIconSizes._();

  /// Bottom navigation destinations.
  static const double navigation = 24;

  /// AppBar / toolbar / search-field chrome.
  static const double standard = 22;

  /// Sort, filter chevrons, dense row metadata.
  static const double metadata = 18;

  /// Leading icons on sticky / filled CTAs.
  static const double cta = 22;

  /// Compact circular quick actions (wishlist heart / remove).
  static const double quickAction = 20;

  /// Header tonal actions & search clear (Share, Close).
  static const double toolbar = 20;

  /// Search clear / field close affordances.
  static const double clear = toolbar;

  /// Section expand / collapse chevrons.
  static const double expand = 20;

  /// Quiet header Add glyph (intentionally lighter than Share).
  static const double headerQuiet = 16;

  /// Secondary outlined Share companion.
  static const double secondaryShare = 15;

  /// Empty-state heroes (Wishlist reference).
  static const double emptyHero = 78;
}

/// Shared hit-target / padding for icon chrome (not decorative badges).
abstract final class AppIconPadding {
  AppIconPadding._();

  /// Default IconButton minimum (Material padded target).
  static const Size buttonMin = Size(40, 40);

  /// Camera suffix inside search field — outer hit vs inner circle.
  static const Size cameraHit = Size(48, 48);
  static const EdgeInsets cameraPadding = EdgeInsets.all(6);
  static const double cameraGlyphWell = 36;

  /// [CatalogQuickActionButton] outer hit vs filled tonal well.
  static const double quickActionHit = 40;
  static const Size quickActionWell = Size(32, 32);
}

/// Shared button recipes for sticky sheet CTAs and secondary Share actions.
///
/// Hierarchy preserved:
/// - Sticky filled/tonal = primary sheet actions (mat radius, 48 min height)
/// - Secondary outlined Share = quiet companion action (field radius)
/// - Header chrome Add / tonal icon Share stay intentionally quieter
abstract final class ShelfyButtonStyles {
  ShelfyButtonStyles._();

  static const double stickyMinHeight = 48;
  static const EdgeInsets stickyPadding = EdgeInsets.symmetric(
    vertical: 14,
    horizontal: 20,
  );

  /// Persistent bottom-sheet Add / Create CTAs.
  static ButtonStyle stickySheetCta() {
    return FilledButton.styleFrom(
      padding: stickyPadding,
      minimumSize: const Size(0, stickyMinHeight),
      tapTargetSize: MaterialTapTargetSize.padded,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.matRadius),
    );
  }

  /// Secondary outlined Share (Insights Collector Card, series figures).
  static ButtonStyle secondaryShare(ColorScheme scheme) {
    return OutlinedButton.styleFrom(
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.fieldRadius),
    );
  }
}
