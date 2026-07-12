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
  static const List<CollectorTypeArchetypeId> tieBreakPriority = [
    CollectorTypeArchetypeId.completionist,
    CollectorTypeArchetypeId.hunter,
    CollectorTypeArchetypeId.loyalist,
    CollectorTypeArchetypeId.curator,
    CollectorTypeArchetypeId.minimalist,
    CollectorTypeArchetypeId.worldbuilder,
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
        'You collect with your heart first — your Wishlist is where the story begins.',
    accentColorLight: Color(0xFFB8A8D8),
    accentColorDark: Color(0xFFC4B4E0),
    icon: Icons.nights_stay_outlined,
  );

  static const hunter = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.hunter,
    displayName: 'The Hunter',
    flavorText:
        'Secret Figures draw you in — you collect them with quiet focus.',
    accentColorLight: Color(0xFFC9A06A),
    accentColorDark: Color(0xFFD4B078),
    icon: Icons.track_changes_outlined,
  );

  static const completionist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.completionist,
    displayName: 'The Completionist',
    flavorText:
        'Every figure matters. You find calm in completing a series.',
    accentColorLight: Color(0xFF7BA88A),
    accentColorDark: Color(0xFF8FBC9C),
    icon: Icons.all_inclusive_outlined,
  );

  static const loyalist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.loyalist,
    displayName: 'The Loyalist',
    flavorText:
        'One universe holds your shelf. Depth over drift — you stay devoted.',
    accentColorLight: Color(0xFF8A9BC4),
    accentColorDark: Color(0xFF9AACD0),
    icon: Icons.favorite_outline,
  );

  static const curator = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.curator,
    displayName: 'The Curator',
    flavorText:
        'You shape a gallery across worlds — each series chosen with intention.',
    accentColorLight: Color(0xFF9A8AB8),
    accentColorDark: Color(0xFFAC9CC8),
    icon: Icons.grid_view_rounded,
  );

  static const trendChaser = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.trendChaser,
    displayName: 'The Trend Chaser',
    flavorText:
        'Fresh drops land on your shelf while the ink is still drying.',
    accentColorLight: Color(0xFFE08A8A),
    accentColorDark: Color(0xFFE89A9A),
    icon: Icons.bolt_outlined,
  );

  static const worldbuilder = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.worldbuilder,
    displayName: 'The Worldbuilder',
    flavorText:
        'You imagine shelves that don\'t exist yet. Instead of fitting into '
        'the catalog, you expand it with worlds of your own.',
    accentColorLight: Color(0xFFB8A0C8),
    accentColorDark: Color(0xFFC8B0D8),
    icon: Icons.public_outlined,
  );

  static const minimalist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.minimalist,
    displayName: 'The Minimalist',
    flavorText:
        'A small shelf, carefully chosen. Quality whispers louder than quantity.',
    accentColorLight: Color(0xFF8A9098),
    accentColorDark: Color(0xFF9CA2AA),
    icon: Icons.crop_square_outlined,
  );

  static const wanderer = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.wanderer,
    displayName: 'The Wanderer',
    flavorText:
        'Your shelf is still unfolding — curiosity leads, judgement stays quiet.',
    accentColorLight: Color(0xFFA8B0C0),
    accentColorDark: Color(0xFFB8C0D0),
    icon: Icons.explore_outlined,
  );

  static const luckyOne = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.luckyOne,
    displayName: 'The Lucky One',
    flavorText:
        'Fortune favors your pulls. Secret Figures find you when others keep searching.',
    accentColorLight: Color(0xFFE8C878),
    accentColorDark: Color(0xFFF0D488),
    icon: Icons.auto_awesome_outlined,
  );
}
