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
      bottom: 'STRONG SIGNAL.',
      motto: 'Complete series counted.',
    ),
    CollectorTypeArchetypeId.hunter => (
      top: 'SECRET FIGURES',
      bottom: 'STAND OUT.',
      motto: 'Secret ownership counted.',
    ),
    CollectorTypeArchetypeId.luckyOne => (
      top: 'EARLY SHELF.',
      bottom: 'SECRET SIGNAL.',
      motto: 'Early Secret ownership counted.',
    ),
    CollectorTypeArchetypeId.dreamer => (
      top: 'FUTURE PLANS',
      bottom: 'STAND OUT.',
      motto: 'Future collecting plans counted.',
    ),
    CollectorTypeArchetypeId.loyalist => (
      top: 'ONE WORLD.',
      bottom: 'STRONGEST SIGNAL.',
      motto: 'Universe depth counted.',
    ),
    CollectorTypeArchetypeId.curator => (
      top: 'MULTIPLE WORLDS.',
      bottom: 'MEASURED DEPTH.',
      motto: 'Universe spread counted.',
    ),
    CollectorTypeArchetypeId.trendChaser => (
      top: 'RECENT RELEASES.',
      bottom: 'STRONG SIGNAL.',
      motto: 'Release dates counted.',
    ),
    CollectorTypeArchetypeId.worldbuilder => (
      top: 'CUSTOM SERIES.',
      bottom: 'STRONG SIGNAL.',
      motto: 'Custom entries counted.',
    ),
    CollectorTypeArchetypeId.minimalist => (
      top: 'SMALL SHELF.',
      bottom: 'CLEAR SIGNAL.',
      motto: 'Series count measured.',
    ),
    CollectorTypeArchetypeId.wanderer => (
      top: 'NO SPECIALIZED',
      bottom: 'PATTERN YET.',
      motto: 'Fallback type recorded.',
    ),
  };
}

String _collectorTypeNumber(CollectorTypeArchetypeId id) {
  final all = CollectorTypeArchetypes.all;
  final index = all.indexWhere((a) => a.id == id);
  final number = (index < 0 ? 1 : index + 1).toString().padLeft(2, '0');
  return '$number/${all.length.toString().padLeft(2, '0')}';
}
