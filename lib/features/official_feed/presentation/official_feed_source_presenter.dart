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

/// Branded source mark when no bundled logo asset exists.
class OfficialFeedSourceMark extends StatelessWidget {
  const OfficialFeedSourceMark({super.key, required this.sourceId});

  final String sourceId;

  static const Color _popmartRed = Color(0xFFE60012);

  @override
  Widget build(BuildContext context) {
    final isPopMart = sourceId == OfficialFeedSources.popmartUs;
    final bg = isPopMart ? _popmartRed : Theme.of(context).colorScheme.primary;
    final label = isPopMart ? 'P' : '?';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
