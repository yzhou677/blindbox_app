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
  wishlistDominates,
  manySecrets,
  fortunateSecrets,
  deepCompletion,
  nearCompletion,
  intentionalSpread,
  compactShelf,
  livingArchive,
  composedShelf,
  freshDrops,
}

extension CollectorTypeReasonKeyCodec on CollectorTypeReasonKey {
  static CollectorTypeReasonKey fromName(String? name) {
    if (name == null || name.isEmpty) {
      return CollectorTypeReasonKey.stillUnfolding;
    }
    return CollectorTypeReasonKey.values.asNameMap()[name] ??
        CollectorTypeReasonKey.stillUnfolding;
  }
}
