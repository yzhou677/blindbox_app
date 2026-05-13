import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Human, shelf-first language for progress — not spreadsheet rows.
abstract final class CollectionProgressVoice {
  /// Primary emotional headline for a series row (replaces raw tallies as the hero read).
  static String seriesHeadline({
    required SeriesDefinition series,
    required SeriesProgressCounts progress,
    required Map<String, TrackedFigure> figureStates,
  }) {
    final total = series.figureCount;
    if (total <= 0) return '';

    final owned = progress.owned;
    final missing = progress.missing;
    final wish = progress.wishlist;
    final secrets = series.figures.where((f) => f.isSecret).toList();
    final ownedSecrets = secrets.where((f) => figureStates[f.id]?.owned == true).length;
    final allSecretsHome = secrets.isNotEmpty && ownedSecrets == secrets.length;

    if (owned >= total) {
      if (allSecretsHome) return 'Complete — chase home';
      if (secrets.isNotEmpty && ownedSecrets > 0) return 'Complete — with a chase on shelf';
      return 'Complete on your shelf';
    }

    if (missing == 0 && wish > 0 && owned < total) {
      return wish == 1 ? 'One wish still out there' : 'A few wishes still out there';
    }

    if (missing == 1) return 'One figure left';
    if (missing == 2) return '2 figures left';

    final ratio = owned / total;
    if (missing > 0 && ratio >= 0.85) return 'Almost complete';

    if (wish > 0 && missing > 0) {
      return wish == 1 ? 'Still hunting one wish' : 'Still hunting a few wishes';
    }

    if (missing > 0) {
      return '$missing figures still to find';
    }

    return 'Growing this series';
  }

  /// Softer supporting copy — light facts, calm tone.
  static String seriesSubline({
    required SeriesDefinition series,
    required SeriesProgressCounts progress,
    required Map<String, TrackedFigure> figureStates,
  }) {
    final total = series.figureCount;
    if (total <= 0) return '';

    final owned = progress.owned;
    final missing = progress.missing;
    final wish = progress.wishlist;
    final secrets = series.figures.where((f) => f.isSecret).toList();
    final ownedSecrets = secrets.where((f) => figureStates[f.id]?.owned == true).length;

    if (owned >= total) {
      return 'Every slot in this series is filled.';
    }

    final parts = <String>[];
    if (owned > 0) parts.add('$owned on shelf');
    if (wish > 0) parts.add('$wish on the hunt list');
    if (missing > 0 && secrets.isNotEmpty && ownedSecrets < secrets.length) {
      final openChase = secrets.length - ownedSecrets;
      if (openChase > 0) parts.add('chase still hiding');
    }
    if (parts.isEmpty) return 'Tap in to log pulls and wishes.';
    return parts.join(' · ');
  }

  /// One calm sentence for the overview card under the stats row.
  static String shelfMoodLine(CollectionSnapshot snap) {
    if (snap.shelfSeries.isEmpty) return '';

    final avg = snap.averageCompletionPercent;
    final seriesCount = snap.shelfSeries.length;
    final allComplete = snap.shelfSeries.every((s) {
      final p = progressForSeries(s, snap.figureStates);
      return s.figureCount > 0 && p.owned >= s.figureCount;
    });

    if (allComplete && seriesCount > 0) {
      return seriesCount == 1
          ? 'This series feels complete — a quiet little win.'
          : 'Every series feels complete — your shelf feels settled.';
    }
    if (avg >= 90) return 'Almost every series feels complete — satisfying.';
    if (avg >= 70) return 'Your shelf is coming together beautifully.';
    if (avg >= 40) return 'Room to grow — each pull adds character.';
    return 'A cozy shelf in progress — enjoy the hunt.';
  }
}
