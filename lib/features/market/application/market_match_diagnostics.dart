import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Debug-only summary of identity matching quality after a sandbox refresh.
final class MarketMatchDiagnostics {
  const MarketMatchDiagnostics({
    required this.total,
    required this.byConfidence,
    required this.ambiguousCount,
    required this.topUnresolvedTokens,
    required this.mercariCount,
  });

  final int total;
  final Map<MarketMatchConfidence, int> byConfidence;
  final int ambiguousCount;
  final List<String> topUnresolvedTokens;
  final int mercariCount;

  factory MarketMatchDiagnostics.summarize(List<MarketListing> rows) {
    final byConf = <MarketMatchConfidence, int>{
      for (final c in MarketMatchConfidence.values) c: 0,
    };
    var ambiguous = 0;
    var mercari = 0;
    final tokenCounts = <String, int>{};

    for (final row in rows) {
      if (row.providerId == 'mercari') mercari++;
      final match = row.catalogMatch;
      if (match == null) {
        byConf[MarketMatchConfidence.none] =
            (byConf[MarketMatchConfidence.none] ?? 0) + 1;
        continue;
      }
      byConf[match.confidence] = (byConf[match.confidence] ?? 0) + 1;
      if (match.matchedFigureId == null &&
          (match.matchedBrandId != null || match.matchedIpId != null)) {
        ambiguous++;
      }
      for (final t in match.unresolvedTokens) {
        tokenCounts[t] = (tokenCounts[t] ?? 0) + 1;
      }
    }

    final topTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return MarketMatchDiagnostics(
      total: rows.length,
      byConfidence: byConf,
      ambiguousCount: ambiguous,
      topUnresolvedTokens: [
        for (final e in topTokens.take(8)) '${e.key} (${e.value})',
      ],
      mercariCount: mercari,
    );
  }

  static void logIfDebug(List<MarketListing> rows) {
    if (!kDebugMode) return;
    final d = MarketMatchDiagnostics.summarize(rows);
    debugPrint(
      'MarketMatchDiagnostics: total=${d.total} mercari=${d.mercariCount} '
      'confidence=$d.byConfidence ambiguous=${d.ambiguousCount} '
      'topUnresolved=${d.topUnresolvedTokens}',
    );
  }
}
