import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Collection shelf visual density / arrangement.
///
/// All layouts consume the same filtered + sorted series lists.
enum CollectionShelfLayout {
  /// Current Series Card presentation (horizontal rails) — default for existing users.
  grid,

  /// Denser vertical grid with simplified cards.
  compactGrid,

  /// Full-width horizontal series rows.
  list,
}

extension CollectionShelfLayoutLabels on CollectionShelfLayout {
  String get menuLabel => switch (this) {
    CollectionShelfLayout.grid => 'Grid',
    CollectionShelfLayout.compactGrid => 'Compact Grid',
    CollectionShelfLayout.list => 'List',
  };

  String get semanticLabel => switch (this) {
    CollectionShelfLayout.grid => 'Grid layout',
    CollectionShelfLayout.compactGrid => 'Compact grid layout',
    CollectionShelfLayout.list => 'List layout',
  };

  IconData get icon => switch (this) {
    CollectionShelfLayout.grid => Symbols.grid_view_rounded,
    CollectionShelfLayout.compactGrid => Symbols.grid_on_rounded,
    CollectionShelfLayout.list => Symbols.view_agenda_rounded,
  };

  static CollectionShelfLayout? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in CollectionShelfLayout.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Responsive column count for Compact Grid.
int collectionCompactGridColumnCount(double maxWidth) {
  if (maxWidth >= 900) return 5;
  if (maxWidth >= 700) return 4;
  if (maxWidth >= 520) return 3;
  return 2;
}
