import 'package:flutter/material.dart';

/// Stable collector identity archetypes (rule-resolved, not live analytics).
enum CollectorTypeArchetypeId {
  dreamer,
  hunter,
  completionist,
  loyalist,
  curator,
  trendChaser,
  worldbuilder,
  minimalist,
  wanderer,
  luckyOne,
}

extension CollectorTypeArchetypeIdCodec on CollectorTypeArchetypeId {
  /// Parses persisted id names, including retired / renamed ids.
  static CollectorTypeArchetypeId fromName(String? name) {
    if (name == null || name.isEmpty) {
      return CollectorTypeArchetypeId.wanderer;
    }
    // Archivist → Worldbuilder (rename).
    if (name == 'archivist') return CollectorTypeArchetypeId.worldbuilder;
    // Daydream Collector retired — Dreamer owns the wishlist fantasy.
    if (name == 'daydreamCollector') return CollectorTypeArchetypeId.dreamer;
    return CollectorTypeArchetypeId.values.asNameMap()[name] ??
        CollectorTypeArchetypeId.wanderer;
  }
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
