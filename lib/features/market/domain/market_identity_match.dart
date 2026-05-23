import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:flutter/foundation.dart';

/// Canonical catalog identity reference for a marketplace listing title.
///
/// Does not replace [MarketListing] or catalog models — only records a match attempt.
@immutable
class MarketIdentityMatch {
  const MarketIdentityMatch({
    this.matchedBrandId,
    this.matchedIpId,
    this.matchedSeriesId,
    this.matchedFigureId,
    required this.confidence,
    required this.score,
    this.matchedAliases = const [],
    this.normalizationSource = 'title',
    this.unresolvedTokens = const [],
  });

  final String? matchedBrandId;
  final String? matchedIpId;
  final String? matchedSeriesId;
  final String? matchedFigureId;
  final MarketMatchConfidence confidence;
  final double score;
  final List<String> matchedAliases;
  final String normalizationSource;
  final List<String> unresolvedTokens;

  bool get hasFigure => matchedFigureId != null && matchedFigureId!.isNotEmpty;

  bool get hasSeries => matchedSeriesId != null && matchedSeriesId!.isNotEmpty;

  factory MarketIdentityMatch.unresolved({
    List<String> unresolvedTokens = const [],
    String normalizationSource = 'title',
  }) {
    return MarketIdentityMatch(
      confidence: MarketMatchConfidence.none,
      score: 0,
      unresolvedTokens: unresolvedTokens,
      normalizationSource: normalizationSource,
    );
  }

  MarketIdentityMatch copyWith({
    String? matchedBrandId,
    String? matchedIpId,
    String? matchedSeriesId,
    String? matchedFigureId,
    MarketMatchConfidence? confidence,
    double? score,
    List<String>? matchedAliases,
    String? normalizationSource,
    List<String>? unresolvedTokens,
  }) {
    return MarketIdentityMatch(
      matchedBrandId: matchedBrandId ?? this.matchedBrandId,
      matchedIpId: matchedIpId ?? this.matchedIpId,
      matchedSeriesId: matchedSeriesId ?? this.matchedSeriesId,
      matchedFigureId: matchedFigureId ?? this.matchedFigureId,
      confidence: confidence ?? this.confidence,
      score: score ?? this.score,
      matchedAliases: matchedAliases ?? this.matchedAliases,
      normalizationSource: normalizationSource ?? this.normalizationSource,
      unresolvedTokens: unresolvedTokens ?? this.unresolvedTokens,
    );
  }
}
