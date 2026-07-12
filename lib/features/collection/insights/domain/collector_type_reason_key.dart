/// Causal key for why a collector type won — resolved in the scorer, not the UI.
///
/// Hero / Reveal map this to localized copy. Never derive “because” from stats
/// in widgets.
enum CollectorTypeReasonKey {
  /// Fallback / empty / low-confidence shelf.
  stillUnfolding,

  /// Scored wanderer: spread + unfinished.
  curiousSpread,

  dominantUniverse,
  highWishlist,
  manySecrets,
  fortunateSecrets,
  deepCompletion,
  nearCompletion,
  intentionalSpread,
  compactShelf,
  /// Custom worlds / notes / personal imagery — Worldbuilder.
  inventedWorlds,
  freshDrops,
}

extension CollectorTypeReasonKeyCodec on CollectorTypeReasonKey {
  static CollectorTypeReasonKey fromName(String? name) {
    if (name == null || name.isEmpty) {
      return CollectorTypeReasonKey.stillUnfolding;
    }
    // Legacy Archivist key → Worldbuilder fantasy.
    if (name == 'livingArchive') {
      return CollectorTypeReasonKey.inventedWorlds;
    }
    // Legacy Daydream Collector key → Dreamer Because.
    if (name == 'wishlistDominates') {
      return CollectorTypeReasonKey.highWishlist;
    }
    return CollectorTypeReasonKey.values.asNameMap()[name] ??
        CollectorTypeReasonKey.stillUnfolding;
  }
}
