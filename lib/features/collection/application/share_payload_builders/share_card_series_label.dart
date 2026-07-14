String shareCardSeriesLabel(String raw, {bool uppercase = false}) {
  var label = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (label.isEmpty) return label;

  label = _dropCatalogSuffixAfterDash(label);
  label = _removeTrailingCatalogWords(label);
  label = label.trim().replaceAll(RegExp(r'\s+'), ' ');

  if (uppercase) return label.toUpperCase();
  return label;
}

String _dropCatalogSuffixAfterDash(String label) {
  final parts = label.split(RegExp(r'\s+-\s+'));
  if (parts.length < 2) return label;
  final suffix = parts.sublist(1).join(' - ').toLowerCase();
  final looksLikeCatalogDescriptor = RegExp(
    r'\b(vinyl|plush|figure|figures|blind box|series|collection|collectible|toy)\b',
  ).hasMatch(suffix);
  return looksLikeCatalogDescriptor ? parts.first : label;
}

String _removeTrailingCatalogWords(String label) {
  final patterns = <RegExp>[
    RegExp(r'\s+collection\s+titans\s+blind\s+box.*$', caseSensitive: false),
    RegExp(r'\s+blind\s+box.*$', caseSensitive: false),
    RegExp(r'\s+series\s+figures.*$', caseSensitive: false),
    RegExp(r'\s+series\s*$', caseSensitive: false),
    RegExp(r'\s+figures\s*$', caseSensitive: false),
    RegExp(r'\s+collection\s*$', caseSensitive: false),
  ];
  var next = label;
  for (final pattern in patterns) {
    next = next.replaceFirst(pattern, '');
  }
  return next;
}
