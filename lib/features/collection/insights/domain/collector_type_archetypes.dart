import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
        'Your future collecting plans are the strongest signal in this reveal.',
    accentColorLight: Color(0xFFB8A8D8),
    accentColorDark: Color(0xFFC4B4E0),
    icon: Symbols.nights_stay_rounded,
  );

  static const hunter = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.hunter,
    displayName: 'The Hunter',
    flavorText: 'Secret Figures are a strong signal in this reveal.',
    accentColorLight: Color(0xFFC9A06A),
    accentColorDark: Color(0xFFD4B078),
    icon: Symbols.track_changes_rounded,
  );

  static const completionist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.completionist,
    displayName: 'The Completionist',
    flavorText:
        'Complete and near-Complete series are the strongest signals in this reveal.',
    accentColorLight: Color(0xFF7BA88A),
    accentColorDark: Color(0xFF8FBC9C),
    icon: Symbols.all_inclusive_rounded,
  );

  static const loyalist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.loyalist,
    displayName: 'The Loyalist',
    flavorText: 'One universe has the strongest presence in this reveal.',
    accentColorLight: Color(0xFF8A9BC4),
    accentColorDark: Color(0xFF9AACD0),
    icon: Symbols.favorite_border_rounded,
  );

  static const curator = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.curator,
    displayName: 'The Curator',
    flavorText:
        'Multiple universes have meaningful representation in this reveal.',
    accentColorLight: Color(0xFF9A8AB8),
    accentColorDark: Color(0xFFAC9CC8),
    icon: Symbols.grid_view_rounded,
  );

  static const trendChaser = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.trendChaser,
    displayName: 'The Trend Chaser',
    flavorText: 'Recent-release series are a strong signal in this reveal.',
    accentColorLight: Color(0xFFE08A8A),
    accentColorDark: Color(0xFFE89A9A),
    icon: Symbols.bolt_rounded,
  );

  static const worldbuilder = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.worldbuilder,
    displayName: 'The Worldbuilder',
    flavorText: 'Custom series are a strong signal in this reveal.',
    accentColorLight: Color(0xFFB8A0C8),
    accentColorDark: Color(0xFFC8B0D8),
    icon: Symbols.public_rounded,
  );

  static const minimalist = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.minimalist,
    displayName: 'The Minimalist',
    flavorText: 'This reveal is based on a small shelf.',
    accentColorLight: Color(0xFF8A9098),
    accentColorDark: Color(0xFF9CA2AA),
    icon: Symbols.crop_square_rounded,
  );

  static const wanderer = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.wanderer,
    displayName: 'The Wanderer',
    flavorText: 'No specialized shelf pattern qualified at this reveal.',
    accentColorLight: Color(0xFFA8B0C0),
    accentColorDark: Color(0xFFB8C0D0),
    icon: Symbols.explore_rounded,
  );

  static const luckyOne = CollectorTypeArchetype(
    id: CollectorTypeArchetypeId.luckyOne,
    displayName: 'The Lucky One',
    flavorText: 'Secret ownership is high for an early shelf.',
    accentColorLight: Color(0xFFE8C878),
    accentColorDark: Color(0xFFF0D488),
    icon: Symbols.auto_awesome_rounded,
  );
}
