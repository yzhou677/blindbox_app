import 'package:blindbox_app/features/collection/application/collection_memory_index.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/application/shelf_relationship_analyzer.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:blindbox_app/features/collection/presentation/collection_memory_editorial.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shelfEmotionalProfileProvider = Provider<ShelfEmotionalProfile>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  return interpretShelf(snap);
});

final shelfRelationshipInsightsProvider =
    Provider<List<ShelfRelationshipInsight>>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  return analyzeShelfRelationships(snap);
});

final collectionMemoryMomentsProvider =
    Provider<List<CollectionMemoryMoment>>((ref) {
  ref.watch(collectionNotifierProvider);
  final snap = ref.read(collectionNotifierProvider);
  return buildCollectionMemoryMoments(snap);
});

final shelfInterpretationLineProvider = Provider<String>((ref) {
  final profile = ref.watch(shelfEmotionalProfileProvider);
  if (profile.interpretationConfidence.index >=
      ShelfInterpretationConfidence.medium.index) {
    return ShelfEditorialVoice.shelfInterpretationLine(profile);
  }
  return '';
});

final shelfMemoryWhisperProvider = Provider<String?>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  return resolveCollectionMemoryWhisper(snap);
});

final collectionMemoryReflectionForSeriesProvider =
    Provider.family<String?, String>((ref, seriesId) {
  final snap = ref.watch(collectionNotifierProvider);
  final store = CollectionMemoryStore.instance.cached;
  ShelfSeries? series;
  for (final s in snap.shelfSeries) {
    if (s.id == seriesId) {
      series = s;
      break;
    }
  }
  if (series == null) return null;

  final progress = progressForSeries(series, snap.figureStates);
  final isComplete =
      series.figureCount > 0 && progress.owned >= series.figureCount;
  var recentlyCompleted = false;
  if (store.lastCompletedSeriesId == seriesId &&
      store.lastCompletedAt != null) {
    final age = DateTime.now().difference(store.lastCompletedAt!);
    recentlyCompleted =
        age <= CollectionMemoryEditorial.recentCompletionWindow;
  }

  return CollectionMemoryEditorial.seriesReflection(
    recentlyCompleted: recentlyCompleted,
    isComplete: isComplete,
    seriesName: series.name,
  );
});

/// Ensures memory store is loaded (call from main after prefs ready).
final collectionMemoryBootstrapProvider = FutureProvider<void>((ref) async {
  await CollectionMemoryStore.instance.ensureLoaded();
});
