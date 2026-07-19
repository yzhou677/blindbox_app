import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class OnDisplayWidgetPayload {
  const OnDisplayWidgetPayload({
    required this.seriesId,
    required this.seriesName,
    required this.ipName,
    required this.brand,
    required this.localCoverPath,
    required this.ownedFigureCount,
    required this.regularOwned,
    required this.regularTotal,
    required this.isComplete,
    required this.isMasterComplete,
  });

  final String seriesId;
  final String seriesName;
  final String ipName;
  final String brand;
  final String localCoverPath;
  final int ownedFigureCount;
  final int regularOwned;
  final int regularTotal;
  final bool isComplete;
  final bool isMasterComplete;

  Map<String, Object> toJson() => <String, Object>{
    'seriesId': seriesId,
    'seriesName': seriesName,
    'ipName': ipName,
    'brand': brand,
    'localCoverPath': localCoverPath,
    'ownedFigureCount': ownedFigureCount,
    'regularOwned': regularOwned,
    'regularTotal': regularTotal,
    'isComplete': isComplete,
    'isMasterComplete': isMasterComplete,
  };

  static String encodeList(List<OnDisplayWidgetPayload> payloads) =>
      jsonEncode(payloads.map((payload) => payload.toJson()).toList());
}
