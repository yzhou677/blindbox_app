import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Local-only id / [imageKey] conventions aligned with Firestore catalog shape.
abstract final class CustomSeriesConventions {
  static const String independentBrandId = 'independent';

  /// Stable snake_case id from user-facing labels (catalog-style).
  static String slugId(String raw, {String fallback = 'custom'}) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return fallback;
    final buf = StringBuffer();
    var prevUnderscore = false;
    for (final code in lower.runes) {
      final ch = String.fromCharCode(code);
      final ok = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      if (ok) {
        buf.write(ch);
        prevUnderscore = false;
      } else if (!prevUnderscore) {
        buf.write('_');
        prevUnderscore = true;
      }
    }
    var out = buf.toString();
    if (out.startsWith('_')) out = out.substring(1);
    if (out.endsWith('_')) out = out.substring(0, out.length - 1);
    return out.isEmpty ? fallback : out;
  }

  static String brandIdFromDisplay(String? brandDisplay) {
    final t = brandDisplay?.trim();
    if (t == null || t.isEmpty) return independentBrandId;
    return slugId(t, fallback: independentBrandId);
  }

  static String ipIdFromDisplay({
    required String seriesDisplayName,
    String? ipDisplayName,
  }) {
    final ip = ipDisplayName?.trim();
    if (ip != null && ip.isNotEmpty) {
      return slugId(ip, fallback: slugId(seriesDisplayName));
    }
    return slugId(seriesDisplayName, fallback: 'custom_ip');
  }

  static String seriesImageKey(String seriesInstanceId) => seriesInstanceId;

  static String figureImageKey(String seriesInstanceId, int index) =>
      '$seriesInstanceId-f-$index';

  /// Shelf rarity line for UI + legacy [ShelfFigure.rarity] field.
  static String rarityLine({required bool isSecret, String? rarityLabel}) {
    final label = rarityLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return isSecret ? 'Secret' : 'Regular';
  }
}

/// Maps a persisted shelf figure into a dialog-editable draft.
CustomFigureDraft customFigureDraftFromShelfFigure(ShelfFigure figure) {
  return CustomFigureDraft(
    displayName: figure.name,
    localImageUri: figure.localImageUri,
    isSecret: figure.isSecret,
    rarityLabel: figure.rarityLabel,
  );
}

/// One user-authored figure slot before commit to the shelf.
class CustomFigureDraft {
  const CustomFigureDraft({
    required this.displayName,
    this.localImageUri,
    this.isSecret = false,
    this.rarityLabel,
  });

  final String displayName;
  final String? localImageUri;
  final bool isSecret;
  final String? rarityLabel;
}
