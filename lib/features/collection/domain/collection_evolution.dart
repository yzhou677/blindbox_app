import 'package:blindbox_app/features/collection/domain/shelf_era.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:flutter/foundation.dart';

/// How the shelf character shifted between two observed eras.
enum CollectionEvolutionKind {
  moodSoftened,
  moodBrightened,
  secretsEmerging,
  universeShift,
}

@immutable
class CollectionEvolution {
  const CollectionEvolution({
    required this.kind,
    required this.priorEra,
    required this.currentMood,
  });

  final CollectionEvolutionKind kind;
  final ShelfEra priorEra;
  final ShelfMood currentMood;
}
