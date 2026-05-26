import 'package:flutter/material.dart';

/// Stable collector identity archetypes (rule-resolved, not live analytics).
enum CollectorTypeArchetypeId {
  dreamer,
  hunter,
  completionist,
  loyalist,
  curator,
  trendChaser,
  archivist,
  minimalist,
  wanderer,
  stylist,
  daydreamCollector,
  luckyOne,
}

/// Display metadata for a resolved collector archetype.
@immutable
class CollectorTypeArchetype {
  const CollectorTypeArchetype({
    required this.id,
    required this.displayName,
    required this.flavorText,
    required this.accentColorLight,
    required this.accentColorDark,
    this.icon,
  });

  final CollectorTypeArchetypeId id;
  final String displayName;
  final String flavorText;
  final Color accentColorLight;
  final Color accentColorDark;
  final IconData? icon;

  Color accentFor(Brightness brightness) =>
      brightness == Brightness.dark ? accentColorDark : accentColorLight;
}
