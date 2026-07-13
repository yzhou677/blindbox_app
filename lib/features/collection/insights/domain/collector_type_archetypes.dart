import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/material.dart';

/// Registry of all collector archetypes (single source of truth).
abstract final class CollectorTypeArchetypes {
  CollectorTypeArchetypes._();

  static const List<CollectorTypeArchetype> all = [
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
  ];

  /// Stable tie-break order when scores tie (earlier = higher priority).
  ///
  /// Worldbuilder ranks above Minimalist: authorship beats compact shelf size
  /// when scores are equal within epsilon.
  static const List<CollectorTypeArchetypeId> tieBreakPriority = [
    CollectorTypeArchetypeId.completionist,
    CollectorTypeArchetypeId.hunter,
    CollectorTypeArchetypeId.loyalist,
    CollectorTypeArchetypeId.curator,
    CollectorTypeArchetypeId.worldbuilder,
    CollectorTypeArchetypeId.minimalist,
    CollectorTypeArchetypeId.trendChaser,
    CollectorTypeArchetypeId.dreamer,
    CollectorTypeArchetypeId.luckyOne,
    CollectorTypeArchetypeId.wanderer,
  ];

  static CollectorTypeArchetype byId(CollectorTypeArchetypeId id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return wanderer;
  }

  static CollectorTypeArchetype? tryByIdName(String? name) {
    if (name == null || name.isEmpty) return null;
    if (name == 'archivist') {
      return byId(CollectorTypeArchetypeId.worldbuilder);
    }
    if (name == 'daydreamCollector') {
      return byId(CollectorTypeArchetypeId.dreamer);
    }
    final id = CollectorTypeArchetypeId.values.asNameMap()[name];
    if (id == null) return null;
    return byId(id);
  }

  static const dreamer = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.dreamer,
    displayName: 'The Dreamer',
    flavorText:
        'You dream about what comes next more than what you already own.',
    accentColorLight: Color(0xFFB8A8D8),
    accentColorDark: Color(0xFFC4B4E0),
    icon: Icons.nights_stay_outlined,
  );

  static const hunter = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.hunter,
    displayName: 'The Hunter',
    flavorText: 'You actively hunt Secrets—and you catch them.',
    accentColorLight: Color(0xFFC9A06A),
    accentColorDark: Color(0xFFD4B078),
    icon: Icons.track_changes_outlined,
  );

  static const completionist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.completionist,
    displayName: 'The Completionist',
    flavorText:
        'Completion defines your shelf. Most of what you track is finished—or nearly there.',
    accentColorLight: Color(0xFF7BA88A),
    accentColorDark: Color(0xFF8FBC9C),
    icon: Icons.all_inclusive_outlined,
  );

  static const loyalist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.loyalist,
    displayName: 'The Loyalist',
    flavorText:
        'One universe clearly defines your shelf. You keep returning to the same world.',
    accentColorLight: Color(0xFF8A9BC4),
    accentColorDark: Color(0xFF9AACD0),
    icon: Icons.favorite_outline,
  );

  static const curator = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.curator,
    displayName: 'The Curator',
    flavorText:
        'You thoughtfully build across multiple universes, giving each one room to grow.',
    accentColorLight: Color(0xFF9A8AB8),
    accentColorDark: Color(0xFFAC9CC8),
    icon: Icons.grid_view_rounded,
  );

  static const trendChaser = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.trendChaser,
    displayName: 'The Trend Chaser',
    flavorText: 'Recent releases define your shelf. You chase what is new.',
    accentColorLight: Color(0xFFE08A8A),
    accentColorDark: Color(0xFFE89A9A),
    icon: Icons.bolt_outlined,
  );

  static const worldbuilder = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.worldbuilder,
    displayName: 'The Worldbuilder',
    flavorText:
        'Your own creations define your shelf. You expand the catalog with worlds of your own.',
    accentColorLight: Color(0xFFB8A0C8),
    accentColorDark: Color(0xFFC8B0D8),
    icon: Icons.public_outlined,
  );

  static const minimalist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.minimalist,
    displayName: 'The Minimalist',
    flavorText:
        'You keep a small, focused shelf and care deeply for what makes the cut.',
    accentColorLight: Color(0xFF8A9098),
    accentColorDark: Color(0xFF9CA2AA),
    icon: Icons.crop_square_outlined,
  );

  static const wanderer = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.wanderer,
    displayName: 'The Wanderer',
    flavorText:
        'You’re still discovering what defines your shelf. Curiosity leads while identity forms.',
    accentColorLight: Color(0xFFA8B0C0),
    accentColorDark: Color(0xFFB8C0D0),
    icon: Icons.explore_outlined,
  );

  static const luckyOne = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.luckyOne,
    displayName: 'The Lucky One',
    flavorText:
        'Luck found you before hunting did. The early chapter before The Hunter.',
    accentColorLight: Color(0xFFE8C878),
    accentColorDark: Color(0xFFF0D488),
    icon: Icons.auto_awesome_outlined,
  );
}
