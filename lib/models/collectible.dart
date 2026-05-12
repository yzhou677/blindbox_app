import 'package:flutter/material.dart';

/// Designer toy / blind box item shown in feeds and detail.
class Collectible {
  const Collectible({
    required this.id,
    required this.name,
    required this.series,
    required this.brand,
    required this.releaseDate,
    required this.imageUrl,
    this.shelfAccent,
  });

  final String id;
  final String name;
  final String series;
  final String brand;
  final DateTime releaseDate;
  final String imageUrl;

  /// Pastel accent for card mat / chips (packaging-adjacent, not harsh primaries).
  final Color? shelfAccent;

  String get heroImageTag => 'collectible-image-$id';

  String get releaseDateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = releaseDate.month;
    return '${months[m - 1]} ${releaseDate.day}, ${releaseDate.year}';
  }
}
