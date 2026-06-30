import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';

/// Copy for catalog availability empty / loading states.
abstract final class CatalogAvailabilityCopy {
  static const String loadingTitle = 'Downloading catalog…';
  static const String loadingBody = 'Loading your collectible catalog.';

  static const String offlineTitle = 'Catalog unavailable';
  static const String offlineBody =
      'Connect to the internet once to download the catalog.';

  static const String retryLabel = 'Retry';

  static const String searchStillDownloading = 'Catalog is still downloading.';
  static const String searchNeedsConnection =
      'Connect once to download the catalog.';

  static const String addSeriesLoading = 'Loading catalog…';
  static const String addSeriesOffline =
      'Connect once to download the catalog.';

  static String searchMessageFor(CatalogAvailability availability) {
    return availability.isOfflineFirstLaunch
        ? searchNeedsConnection
        : searchStillDownloading;
  }

  static String addSeriesMessageFor(CatalogAvailability availability) {
    return availability.isOfflineFirstLaunch
        ? addSeriesOffline
        : addSeriesLoading;
  }
}
