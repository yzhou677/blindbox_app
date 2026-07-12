import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';

/// Bundled mascot illustrations for Collector Types (presentation assets).
///
/// Every [CollectorTypeArchetypeId] maps to a circular vinyl-toy illustration
/// under [assets/insights/collector_types/]. Render via [CollectorTypeAvatar].
abstract final class CollectorTypeMascotAssets {
  CollectorTypeMascotAssets._();

  static const _dir = 'assets/insights/collector_types';

  static String? assetPathFor(CollectorTypeArchetypeId id) {
    return switch (id) {
      CollectorTypeArchetypeId.dreamer => '$_dir/dreamer.png',
      CollectorTypeArchetypeId.hunter => '$_dir/hunter.png',
      CollectorTypeArchetypeId.completionist => '$_dir/completionist.png',
      CollectorTypeArchetypeId.loyalist => '$_dir/loyalist.png',
      CollectorTypeArchetypeId.curator => '$_dir/curator.png',
      CollectorTypeArchetypeId.trendChaser => '$_dir/trend_chaser.png',
      CollectorTypeArchetypeId.worldbuilder => '$_dir/worldbuilder.png',
      CollectorTypeArchetypeId.minimalist => '$_dir/minimalist.png',
      CollectorTypeArchetypeId.wanderer => '$_dir/wanderer.png',
      CollectorTypeArchetypeId.luckyOne => '$_dir/lucky_one.png',
    };
  }
}
