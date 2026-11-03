import 'dart:io';

import 'package:blindbox_app/features/collection/application/shelf_backup_commit.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/foundation.dart';

/// Applies a [ShelfRecoveryPackContents] into local prefs + vault.
abstract final class ShelfRecoveryImport {
  ShelfRecoveryImport._();

  /// Restores thumbs / memory / UI prefs, then writes snapshot last.
  ///
  /// Snapshot prefs are the "import finished" marker — any earlier failure
  /// leaves them unset so cold-start can offer the pack again.
  ///
  /// Vault thumbs are always installed as `<id>.jpg`; snapshot vault refs are
  /// rewritten to match before save.
  ///
  /// Test hooks live on [ShelfBackupCommit].
  static Future<CollectionSnapshot> apply(ShelfRecoveryPackContents pack) {
    return ShelfBackupCommit.apply(
      snapshot: pack.snapshot,
      memoryJson: pack.memoryJson,
      uiPrefsJson: pack.uiPrefsJson,
      manageGate: false,
      transformSnapshot: rewriteVaultRefsToRecoveredJpg,
      installMedia: () async {
        await ShelfMediaVault.ensureReady();
        for (final id in pack.mediaIds) {
          final file = File(ShelfRecoveryPack.mediaFilePath(pack.packPath, id));
          if (!await file.exists()) continue;
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) continue;
          await ShelfMediaVault.installRecoveredThumb(id: id, thumbBytes: bytes);
        }
      },
    );
  }

  /// Maps vault relative refs to `shelf_media/originals/<id>.jpg`.
  @visibleForTesting
  static CollectionSnapshot rewriteVaultRefsToRecoveredJpg(
    CollectionSnapshot snapshot,
  ) {
    return snapshot.copyWith(
      shelfSeries: [
        for (final series in snapshot.shelfSeries)
          ShelfSeries(
            id: series.id,
            name: series.name,
            brand: series.brand,
            ipName: series.ipName,
            figures: [
              for (final figure in series.figures)
                ShelfFigure(
                  id: figure.id,
                  seriesId: figure.seriesId,
                  name: figure.name,
                  imageUrl: figure.imageUrl,
                  localImageUri: ShelfMediaVault.recoveredJpgRef(
                    figure.localImageUri,
                  ),
                  rarity: figure.rarity,
                  isSecret: figure.isSecret,
                  rarityLabel: figure.rarityLabel,
                  imageKey: figure.imageKey,
                  taxonomyBrandId: figure.taxonomyBrandId,
                  taxonomyIpId: figure.taxonomyIpId,
                  catalogFigureTemplateId: figure.catalogFigureTemplateId,
                ),
            ],
            shelfAccent: series.shelfAccent,
            notes: series.notes,
            catalogTemplateId: series.catalogTemplateId,
            taxonomyBrandId: series.taxonomyBrandId,
            taxonomyIpId: series.taxonomyIpId,
            imageKey: series.imageKey,
            customCoverImageUri: ShelfMediaVault.recoveredJpgRef(
              series.customCoverImageUri,
            ),
            releaseDate: series.releaseDate,
          ),
      ],
    );
  }
}
