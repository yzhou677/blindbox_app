import 'package:blindbox_app/models/toy_series_highlight.dart';
import 'package:flutter/material.dart';

/// Local-only series universe rail (replace with catalog API later).
final List<ToySeriesHighlight> mockTrendingSeries = [
  ToySeriesHighlight(
    id: 'series-skullpanda',
    name: 'Skullpanda',
    brand: 'POP MART',
    figureCount: 128,
    accent: const Color(0xFFE8E4F8),
    tagline: 'Moody worlds',
  ),
  ToySeriesHighlight(
    id: 'series-hirono',
    name: 'Hirono',
    brand: 'POP MART',
    figureCount: 86,
    accent: const Color(0xFFF2E8DC),
    tagline: 'Soft stories',
  ),
  ToySeriesHighlight(
    id: 'series-labubu',
    name: 'The Monsters · Labubu',
    brand: 'POP MART',
    figureCount: 204,
    accent: const Color(0xFFE4F2EA),
    tagline: 'Playful chaos',
  ),
  ToySeriesHighlight(
    id: 'series-dimoo',
    name: 'Dimoo',
    brand: 'POP MART',
    figureCount: 72,
    accent: const Color(0xFFE4EDFA),
    tagline: 'Dreamy journeys',
  ),
  ToySeriesHighlight(
    id: 'series-molly',
    name: 'Molly',
    brand: 'POP MART',
    figureCount: 94,
    accent: const Color(0xFFFCE4EC),
    tagline: 'Icon energy',
  ),
  ToySeriesHighlight(
    id: 'series-liita',
    name: 'Liita',
    brand: 'TNTSPACE',
    figureCount: 38,
    accent: const Color(0xFFEAF6FB),
    tagline: 'Fresh voices',
  ),
];
