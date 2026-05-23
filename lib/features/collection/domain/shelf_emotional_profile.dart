import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:flutter/foundation.dart';

/// Derived shelf interpretation — not canonical collector identity.
@immutable
class ShelfEmotionalProfile {
  const ShelfEmotionalProfile({
    required this.shelfMood,
    required this.interpretationConfidence,
    required this.secretOwnedCount,
    required this.secretSlotCount,
    required this.seriesCompleteCount,
    required this.editorialThemes,
    this.dominantBrandId,
    this.dominantIpId,
  });

  final ShelfMood shelfMood;
  final ShelfInterpretationConfidence interpretationConfidence;
  final String? dominantBrandId;
  final String? dominantIpId;
  final int secretOwnedCount;
  final int secretSlotCount;
  final int seriesCompleteCount;
  final List<String> editorialThemes;

  bool get hasSecretAffinity =>
      secretSlotCount > 0 && secretOwnedCount > 0;

  bool themeIncludes(String tag) => editorialThemes.contains(tag);
}

/// Tags for editorial copy rules only.
abstract final class ShelfEditorialTheme {
  static const secrets = 'secrets';
  static const nearComplete = 'nearComplete';
  static const multiUniverse = 'multiUniverse';
  static const wishlistHeavy = 'wishlistHeavy';
  static const harmony = 'harmony';
}
