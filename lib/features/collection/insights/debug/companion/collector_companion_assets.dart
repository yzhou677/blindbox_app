/// Layered companion art pack (shared 1024 canvas).
///
/// Future Collector Types can supply a different pack with the same layout.
/// Blink layers are intentionally omitted — Completionist eyes stay closed.
class CollectorCompanionAssets {
  const CollectorCompanionAssets({
    required this.body,
    required this.arms,
    required this.trophy,
    required this.head,
    required this.crown,
  });

  final String body;
  final String arms;
  final String trophy;
  final String head;
  final String crown;

  /// Completionist layered pack under insights assets.
  static const completionist = CollectorCompanionAssets(
    body: 'assets/insights/collector_types/completionist/body.png',
    arms: 'assets/insights/collector_types/completionist/arms.png',
    trophy: 'assets/insights/collector_types/completionist/trophy.png',
    head: 'assets/insights/collector_types/completionist/head.png',
    crown: 'assets/insights/collector_types/completionist/crown.png',
  );
}
