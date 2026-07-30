import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';

/// Counts distinct Collection Series that share [ipId] via stable taxonomy.
///
/// ## Rules
/// - Match only [ShelfSeries.taxonomyIpId] == trimmed [ipId] (never display names).
/// - Count Series rows present on the shelf — not figures or quantities.
/// - Deduplicate by stable catalog/drop identity when available, else shelf row id.
/// - Custom / untagged rows without a non-empty [ShelfSeries.taxonomyIpId] are
///   excluded.
/// - Returns `null` when the count is zero (callers omit the section).
IpIntroductionIpSeriesCount? resolveIpIntroductionIpSeriesCount({
  required String ipId,
  required CollectionSnapshot snapshot,
}) {
  final target = ipId.trim();
  if (target.isEmpty) return null;

  final seen = <String>{};
  for (final series in snapshot.shelfSeries) {
    final tax = series.taxonomyIpId?.trim() ?? '';
    if (tax.isEmpty || tax != target) continue;
    seen.add(_stableSeriesDedupKey(series));
  }
  if (seen.isEmpty) return null;
  return IpIntroductionIpSeriesCount(seriesCount: seen.length);
}

/// Stable key for counting one logical Series once on the shelf.
String _stableSeriesDedupKey(ShelfSeries series) {
  final catalogId = recommendationCatalogSeriesId(series);
  if (catalogId != null && catalogId.isNotEmpty) return 'catalog:$catalogId';

  final template = series.catalogTemplateId?.trim() ?? '';
  if (template.isNotEmpty) return 'template:$template';

  return 'shelf:${series.id}';
}
