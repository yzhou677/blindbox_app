import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:crypto/crypto.dart';

/// Content fingerprint for exploration-slot rotation.
///
/// Changes when catalog series membership changes (new series, removals).
/// Paired with [profileHash] — not calendar time.
String catalogExplorationFingerprint(CatalogSeedBundle bundle) {
  final ids = bundle.series.map((series) => series.id).toList()..sort();
  return sha256.convert(utf8.encode(ids.join(','))).toString();
}
