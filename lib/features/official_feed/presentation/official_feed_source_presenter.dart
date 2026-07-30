import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:flutter/material.dart';

/// Secondary deck line under the source row — content-type label when known.
String officialFeedDeckLine(OfficialFeedItem item) {
  if (item.sourceId == OfficialFeedSources.popmartUs) {
    return inferOfficialFeedContentTypeLabel(item);
  }
  return item.sourceLabel;
}

/// Host label for footer metadata (e.g. `popmart.com`).
String officialFeedHostLabel(String officialUrl) {
  final host = Uri.tryParse(officialUrl.trim())?.host ?? '';
  if (host.isEmpty) return '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Bundled source logos for Official Update marks (optional per brand).
String? officialFeedSourceLogoAsset(String sourceId) {
  return switch (sourceId) {
    OfficialFeedSources.popmartUs => 'assets/official_feed/popmart_logo.png',
    OfficialFeedSources.tntspaceUs => 'assets/official_feed/tntspace_logo.png',
    OfficialFeedSources.toptoyUs => 'assets/official_feed/toptoy_logo.png',
    _ => null,
  };
}

/// Branded source mark — logo asset when bundled, else letter chip.
class OfficialFeedSourceMark extends StatelessWidget {
  const OfficialFeedSourceMark({super.key, required this.sourceId});

  final String sourceId;

  static const Color _popmartRed = Color(0xFFE60012);
  static const Color _tntspaceInk = Color(0xFF1A1A1A);
  static const Color _toptoyBlue = Color(0xFF2F6FED);
  static const Color _toptoyYellow = Color(0xFFFFE100);
  static const double _size = 28;

  /// True when the asset already fills a colored mark (no inset padding).
  bool get _edgeToEdgeLogo =>
      sourceId == OfficialFeedSources.toptoyUs ||
      sourceId == OfficialFeedSources.popmartUs;

  Color get _logoBackdrop {
    return switch (sourceId) {
      OfficialFeedSources.popmartUs => _popmartRed,
      OfficialFeedSources.toptoyUs => _toptoyYellow,
      _ => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final logoAsset = officialFeedSourceLogoAsset(sourceId);
    if (logoAsset != null) {
      final radius = BorderRadius.circular(6);
      final image = Image.asset(
        logoAsset,
        fit: _edgeToEdgeLogo ? BoxFit.cover : BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _LetterMark(sourceId: sourceId),
      );
      return SizedBox(
        width: _size,
        height: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _logoBackdrop,
            borderRadius: radius,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: _edgeToEdgeLogo
                ? image
                : Padding(padding: const EdgeInsets.all(3), child: image),
          ),
        ),
      );
    }

    return _LetterMark(sourceId: sourceId);
  }
}

class _LetterMark extends StatelessWidget {
  const _LetterMark({required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (sourceId) {
      OfficialFeedSources.popmartUs => (
        OfficialFeedSourceMark._popmartRed,
        'P',
      ),
      OfficialFeedSources.tntspaceUs => (
        OfficialFeedSourceMark._tntspaceInk,
        'T',
      ),
      OfficialFeedSources.toptoyUs => (
        OfficialFeedSourceMark._toptoyBlue,
        'TT',
      ),
      _ => (Theme.of(context).colorScheme.primary, '?'),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        width: OfficialFeedSourceMark._size,
        height: OfficialFeedSourceMark._size,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: label.length > 1 ? 11 : 13,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
