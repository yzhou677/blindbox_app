import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Scans snapshot vault refs (`localImageUri` / `customCoverImageUri`).
abstract final class ShelfVaultRefs {
  ShelfVaultRefs._();

  /// Unique vault media ids referenced by [snapshot], order-stable by first
  /// encounter (series cover, then figures).
  static List<String> referencedIds(CollectionSnapshot snapshot) {
    final seen = <String>{};
    final out = <String>[];
    void consider(String? ref) {
      final id = ShelfMediaVault.idFromRef(ref);
      if (id == null || !seen.add(id)) return;
      out.add(id);
    }

    for (final series in snapshot.shelfSeries) {
      consider(series.customCoverImageUri);
      for (final figure in series.figures) {
        consider(figure.localImageUri);
      }
    }
    return out;
  }

  /// All non-empty vault-relative refs in encounter order (may repeat ids).
  static Iterable<String> referencedVaultRefs(CollectionSnapshot snapshot) sync* {
    for (final series in snapshot.shelfSeries) {
      final cover = series.customCoverImageUri?.trim();
      if (cover != null &&
          cover.isNotEmpty &&
          ShelfMediaVault.isVaultRef(cover)) {
        yield cover;
      }
      for (final figure in series.figures) {
        final local = figure.localImageUri?.trim();
        if (local != null &&
            local.isNotEmpty &&
            ShelfMediaVault.isVaultRef(local)) {
          yield local;
        }
      }
    }
  }
}
