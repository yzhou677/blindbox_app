import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves a [SeriesRelease] for a given drop/collectible id (composition root supplies impl).
typedef SeriesReleaseLookup = SeriesRelease? Function(String dropId);

SeriesRelease? _defaultSeriesReleaseLookup(String dropId) => null;

/// App must override with real data (e.g. mock or API) via [ProviderScope.overrides].
final seriesReleaseLookupProvider = Provider<SeriesReleaseLookup>(
  (ref) => _defaultSeriesReleaseLookup,
);
