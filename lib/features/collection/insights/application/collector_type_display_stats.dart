import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';

/// Whether [memory]'s reveal-frozen stats JSON may be shown as-is.
///
/// Shared by display fallback and `needsReveal` (provider + reveal VM).
bool memoryCollectorTypeStatsAreCurrent(CollectionMemoryData memory) {
  Map<String, dynamic>? statsMap;
  final raw = memory.collectorTypeStatsJson;
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        statsMap = decoded;
      } else if (decoded is Map) {
        statsMap = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      statsMap = null;
    }
  }
  return collectorTypeStatsAreCurrent(
    storedVersion: memory.collectorTypeStatsVersion,
    statsJson: statsMap,
  );
}

/// Resolve which stats Insights should **display**.
///
/// Identity (archetype / reason / signature / reveal time) stays frozen in
/// [storedIdentity]. Derived shelf numbers use frozen JSON only when
/// [collectorTypeStatsAreCurrent]; otherwise they are rebuilt from the live
/// shelf — prefs are **not** rewritten.
CollectorTypeStats resolveCollectorTypeDisplayStats({
  required CollectorTypeIdentity storedIdentity,
  required CollectionMemoryData memory,
  required CollectionSnapshot snapshot,
  required ShelfEmotionalProfile profile,
  CatalogSeedBundle? catalog,
}) {
  if (memoryCollectorTypeStatsAreCurrent(memory)) {
    return storedIdentity.stats;
  }

  return buildCollectorTypeStats(snapshot, profile, catalog);
}
