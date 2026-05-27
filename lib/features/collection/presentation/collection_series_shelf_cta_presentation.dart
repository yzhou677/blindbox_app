import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Visual semantics for shelf add / owned CTAs — shared across Home, Search, Add sheet.
enum OwnershipShelfCtaVisualState {
  addable,
  owned,
  disabled,
}

/// Layout profile — same ownership truth, different chrome per surface.
enum CollectionSeriesShelfCtaLayout {
  /// Compact trailing chip on catalog search / recommendation rows.
  compactTrailing,

  /// Home Latest Drops rail icon control.
  homeReleaseIcon,

  /// Home release detail filled button.
  homeReleaseFilled,

  /// Catalog browse (owned → preview only).
  catalogBrowse,

  /// Sticky bottom action on catalog series preview sheets.
  previewSticky,
}

/// Immutable presentation contract for collection ownership CTAs.
class CollectionSeriesShelfCtaPresentation {
  const CollectionSeriesShelfCtaPresentation({
    required this.visualState,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.semanticsLabel,
    required this.usePrimaryTint,
  });

  final OwnershipShelfCtaVisualState visualState;
  final String label;
  final IconData icon;
  final bool enabled;
  final String semanticsLabel;

  /// When true, trailing chip uses primary-tinted fill (addable). When false, muted owned/disabled.
  final bool usePrimaryTint;

  bool get isOwned => visualState == OwnershipShelfCtaVisualState.owned;
  bool get isAddable => visualState == OwnershipShelfCtaVisualState.addable;

  /// Derives label/icon/enabled/tint from [match] for [layout].
  factory CollectionSeriesShelfCtaPresentation.fromOwnership(
    CollectionSeriesOwnershipMatch match, {
    required CollectionSeriesShelfCtaLayout layout,
  }) {
    if (match.owned) {
      return switch (layout) {
        CollectionSeriesShelfCtaLayout.compactTrailing =>
          const CollectionSeriesShelfCtaPresentation(
            visualState: OwnershipShelfCtaVisualState.owned,
            label: 'In collection',
            icon: Icons.check_rounded,
            enabled: false,
            semanticsLabel: 'Already in your collection',
            usePrimaryTint: false,
          ),
        CollectionSeriesShelfCtaLayout.homeReleaseIcon =>
          CollectionSeriesShelfCtaPresentation(
            visualState: OwnershipShelfCtaVisualState.owned,
            label: '',
            icon: match.removableViaReleaseCta
                ? Icons.bookmark_added_rounded
                : Icons.check_circle_rounded,
            enabled: true,
            semanticsLabel: match.removableViaReleaseCta
                ? 'Remove from collection'
                : 'Already in your collection',
            usePrimaryTint: false,
          ),
        CollectionSeriesShelfCtaLayout.homeReleaseFilled =>
          CollectionSeriesShelfCtaPresentation(
            visualState: OwnershipShelfCtaVisualState.owned,
            label: 'In your collection',
            icon: Icons.check_rounded,
            enabled: match.removableViaReleaseCta,
            semanticsLabel: 'Already in your collection',
            usePrimaryTint: false,
          ),
        CollectionSeriesShelfCtaLayout.catalogBrowse =>
          const CollectionSeriesShelfCtaPresentation(
            visualState: OwnershipShelfCtaVisualState.owned,
            label: 'View',
            icon: Icons.chevron_right_rounded,
            enabled: true,
            semanticsLabel: 'View series in your collection',
            usePrimaryTint: false,
          ),
        CollectionSeriesShelfCtaLayout.previewSticky =>
          const CollectionSeriesShelfCtaPresentation(
            visualState: OwnershipShelfCtaVisualState.owned,
            label: 'In collection',
            icon: Icons.check_rounded,
            enabled: false,
            semanticsLabel: 'Already in your collection',
            usePrimaryTint: false,
          ),
      };
    }

    return switch (layout) {
      CollectionSeriesShelfCtaLayout.compactTrailing =>
        const CollectionSeriesShelfCtaPresentation(
          visualState: OwnershipShelfCtaVisualState.addable,
          label: 'Add',
          icon: Icons.add_rounded,
          enabled: true,
          semanticsLabel: 'Add to collection',
          usePrimaryTint: true,
        ),
      CollectionSeriesShelfCtaLayout.homeReleaseIcon =>
        const CollectionSeriesShelfCtaPresentation(
          visualState: OwnershipShelfCtaVisualState.addable,
          label: '',
          icon: Icons.add_circle_outline_rounded,
          enabled: true,
          semanticsLabel: 'Add to my collection',
          usePrimaryTint: true,
        ),
      CollectionSeriesShelfCtaLayout.homeReleaseFilled =>
        const CollectionSeriesShelfCtaPresentation(
          visualState: OwnershipShelfCtaVisualState.addable,
          label: 'Add to my collection',
          icon: Icons.add_rounded,
          enabled: true,
          semanticsLabel: 'Add to my collection',
          usePrimaryTint: true,
        ),
      CollectionSeriesShelfCtaLayout.catalogBrowse =>
        const CollectionSeriesShelfCtaPresentation(
          visualState: OwnershipShelfCtaVisualState.addable,
          label: 'Browse',
          icon: Icons.chevron_right_rounded,
          enabled: true,
          semanticsLabel: 'Browse series',
          usePrimaryTint: true,
        ),
      CollectionSeriesShelfCtaLayout.previewSticky =>
        const CollectionSeriesShelfCtaPresentation(
          visualState: OwnershipShelfCtaVisualState.addable,
          label: 'Add to shelf',
          icon: Icons.add_rounded,
          enabled: true,
          semanticsLabel: 'Add to shelf',
          usePrimaryTint: true,
        ),
    };
  }

  /// Resolves ownership then presentation — single entry for call sites.
  static CollectionSeriesShelfCtaPresentation resolve({
    required CollectionSnapshot snapshot,
    required CollectionSeriesShelfCtaLayout layout,
    required String catalogTemplateId,
    Iterable<String> alternateCatalogTemplateIds = const [],
    required String seriesName,
    required String brandName,
    String? taxonomyBrandId,
    String? taxonomyIpId,
  }) {
    final match = resolveCollectionSeriesOwnership(
      snapshot: snapshot,
      catalogTemplateId: catalogTemplateId,
      alternateCatalogTemplateIds: alternateCatalogTemplateIds,
      seriesName: seriesName,
      brandName: brandName,
      taxonomyBrandId: taxonomyBrandId,
      taxonomyIpId: taxonomyIpId,
    );
    return CollectionSeriesShelfCtaPresentation.fromOwnership(
      match,
      layout: layout,
    );
  }
}
