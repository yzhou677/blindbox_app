import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:flutter/foundation.dart';

/// Lightweight snapshot of shelf emotional character at a point in time.
@immutable
class ShelfEra {
  const ShelfEra({
    required this.shelfMood,
    required this.seriesCount,
    required this.secretOwnedCount,
    this.dominantIpId,
    this.recordedAt,
  });

  final ShelfMood shelfMood;
  final int seriesCount;
  final int secretOwnedCount;
  final String? dominantIpId;
  final DateTime? recordedAt;
}
