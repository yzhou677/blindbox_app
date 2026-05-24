import 'package:blindbox_app/features/market/data/chasers/market_chasers_config.dart';
import 'package:flutter/foundation.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';
import 'package:blindbox_app/features/market/taxonomy/market_filter_visibility.dart';
import 'package:blindbox_app/features/market/taxonomy/market_taxonomy_adapter.dart';

/// One IP-specific browse probe for Phase 1 chasers scoring.
@immutable
class ChasersProbeTarget {
  const ChasersProbeTarget({
    required this.brandId,
    required this.ipId,
    required this.brandLabel,
    required this.ipLabel,
    required this.hintTokens,
  });

  final String brandId;
  final String ipId;
  final String brandLabel;
  final String ipLabel;
  final List<String> hintTokens;
}

/// UI-visible brand + IP pairs only — excludes Any IP / hidden rails.
List<ChasersProbeTarget> buildChasersProbeTargets() {
  final brandRows = MarketTaxonomyAdapter.buildFilterBrandRows();
  final brandLabels = {
    for (final b in brandRows) b.id: b.displayLabel,
  };
  final out = <ChasersProbeTarget>[];

  for (final brand in brandRows) {
    final brandIpSet = brand.supportedIpIds.toSet();
    for (final ipId in brand.supportedIpIds) {
      if (!MarketFilterVisibility.shouldShowIpOnFilterRail(ipId, brandIpSet)) {
        continue;
      }
      final ip = MarketTaxonomy.ipById(ipId);
      if (ip == null) continue;
      IpTaxonomy? registryIp;
      for (final row in IpTaxonomyRegistry.all) {
        if (row.id == ipId) {
          registryIp = row;
          break;
        }
      }
      final hints = <String>[
        ip.displayLabel,
        if (registryIp != null) ...registryIp.aliases,
      ];
      out.add(
        ChasersProbeTarget(
          brandId: brand.id,
          ipId: ipId,
          brandLabel: brandLabels[brand.id] ?? brand.id,
          ipLabel: ip.displayLabel,
          hintTokens: hints,
        ),
      );
    }
  }
  return _prioritizeChaserProbes(out);
}

/// High-signal IPs first so the rail can hydrate before slower probes finish.
List<ChasersProbeTarget> _prioritizeChaserProbes(List<ChasersProbeTarget> targets) {
  final priorityKeys = MarketChasersConfig.probePriorityKeys;

  int rank(ChasersProbeTarget target) {
    final key = '${target.brandId}|${target.ipId}';
    final idx = priorityKeys.indexOf(key);
    return idx >= 0 ? idx : priorityKeys.length;
  }

  final sorted = [...targets]
    ..sort((a, b) {
      final byPriority = rank(a).compareTo(rank(b));
      if (byPriority != 0) return byPriority;
      return a.ipLabel.compareTo(b.ipLabel);
    });
  return sorted;
}
