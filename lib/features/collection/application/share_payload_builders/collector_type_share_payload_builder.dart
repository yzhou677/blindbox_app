import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_mascot_assets.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';
import 'package:flutter/material.dart';

CollectorTypeSharePayload? buildCollectorTypeSharePayload(
  CollectorTypeIdentity? identity, {
  Brightness brightness = Brightness.light,
}) {
  if (identity == null) return null;
  final healed = identity.healed();
  final archetype = CollectorTypeArchetypes.byId(healed.archetypeId);
  final mascot = CollectorTypeMascotAssets.assetPathFor(healed.archetypeId);
  if (mascot == null || mascot.isEmpty) return null;
  final statement = _collectorTypeStatement(healed.archetypeId);
  final stats = healed.stats;

  return CollectorTypeSharePayload(
    archetypeId: healed.archetypeId,
    displayName: archetype.displayName,
    label: 'SHELFY IDENTITY CARD · ${_collectorTypeNumber(healed.archetypeId)}',
    statementTop: statement.top,
    statementBottom: statement.bottom,
    officialExplanation: CollectorTypeCopy.becauseLineFor(healed),
    motto: statement.motto,
    metadata:
        'OWNED ${stats.totalOwned} · COMPLETE ${stats.completedSeriesCount} · MASTER ${stats.masterCompleteSeriesCount}',
    mascotAssetPath: mascot,
    accent: archetype.accentFor(brightness),
  );
}

({String top, String bottom, String motto}) _collectorTypeStatement(
  CollectorTypeArchetypeId id,
) {
  return switch (id) {
    CollectorTypeArchetypeId.completionist => (
      top: 'COMPLETED?',
      bottom: 'NOT ENOUGH.',
      motto: 'Every last piece.',
    ),
    CollectorTypeArchetypeId.hunter => (
      top: 'SOME GET LUCKY.',
      bottom: 'YOU GO LOOKING.',
      motto: 'Secret by secret.',
    ),
    CollectorTypeArchetypeId.luckyOne => (
      top: 'WAS IT LUCK?',
      bottom: 'ABSOLUTELY.',
      motto: 'Some shelves sparkle early.',
    ),
    CollectorTypeArchetypeId.dreamer => (
      top: 'WISHLIST FIRST.',
      bottom: 'WALLET LATER.',
      motto: 'The shelf starts in your head.',
    ),
    CollectorTypeArchetypeId.loyalist => (
      top: 'ONE WORLD.',
      bottom: 'NO REGRETS.',
      motto: 'Home shelf, chosen universe.',
    ),
    CollectorTypeArchetypeId.curator => (
      top: 'NOT RANDOM.',
      bottom: 'CURATED.',
      motto: 'Every world gets its frame.',
    ),
    CollectorTypeArchetypeId.trendChaser => (
      top: 'NEW DROP?',
      bottom: 'ALREADY WATCHING.',
      motto: 'Fresh finds first.',
    ),
    CollectorTypeArchetypeId.worldbuilder => (
      top: 'DOESN\'T EXIST?',
      bottom: 'MAKE IT.',
      motto: 'Your shelf has authorship.',
    ),
    CollectorTypeArchetypeId.minimalist => (
      top: 'LESS SHELF.',
      bottom: 'MORE TASTE.',
      motto: 'Only what earns the space.',
    ),
    CollectorTypeArchetypeId.wanderer => (
      top: 'NO FIXED PATH.',
      bottom: 'GOOD FINDS.',
      motto: 'Curiosity leads.',
    ),
  };
}

String _collectorTypeNumber(CollectorTypeArchetypeId id) {
  final all = CollectorTypeArchetypes.all;
  final index = all.indexWhere((a) => a.id == id);
  final number = (index < 0 ? 1 : index + 1).toString().padLeft(2, '0');
  return '$number/${all.length.toString().padLeft(2, '0')}';
}
