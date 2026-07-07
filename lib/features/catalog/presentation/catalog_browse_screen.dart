import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_browse_launch.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_experience.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_host_actions.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home entry: catalog search — series preview — figure gallery.
class CatalogBrowseScreen extends ConsumerWidget {
  const CatalogBrowseScreen({super.key, this.launch});

  final CatalogBrowseLaunch? launch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CatalogSearchExperience(
      presentation: CatalogSearchPresentation.discoverScreen,
      idleBody: CatalogSearchIdleBody.recentSearches,
      initialQuery: launch?.initialQuery,
      actions: _discoverActions(ref),
    );
  }

  static CatalogSearchHostActions _discoverActions(WidgetRef ref) {
    Future<void> openPreview(
      BuildContext context, {
      required String seriesId,
      String? searchQuery,
    }) async {
      final template = ref.read(catalogSeriesTemplateProvider(seriesId));
      if (template == null) return;

      final notifier = ref.read(collectionNotifierProvider.notifier);
      final snap = ref.read(collectionNotifierProvider);
      final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
        snapshot: snap,
        layout: CollectionSeriesShelfCtaLayout.previewSticky,
        catalogTemplateId: seriesId,
        seriesName: template.name,
        brandName: template.brand,
        taxonomyBrandId: template.taxonomyBrandId,
        taxonomyIpId: template.taxonomyIpId,
      );

      await showCollectibleBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
        builder: (ctx, scroll) => CatalogSeriesPreviewSheet(
          series: template,
          shelfCta: shelfCta,
          onAdd: () => commitCatalogSeriesToShelf(notifier, template),
        ),
      );
    }

    return CatalogSearchHostActions(
      ctaLayout: CollectionSeriesShelfCtaLayout.catalogBrowse,
      onOpenPreview: openPreview,
      onShelfCtaPressed: openPreview,
    );
  }
}
