import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionSeriesShelfCtaPresentation', () {
    test('owned compact trailing never looks addable', () {
      const match = CollectionSeriesOwnershipMatch.owned(
        kind: CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
        matchedSeriesId: 's1',
        matchedCatalogTemplateId: 'series_a',
      );
      final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
        match,
        layout: CollectionSeriesShelfCtaLayout.compactTrailing,
      );

      expect(cta.visualState, OwnershipShelfCtaVisualState.owned);
      expect(cta.label, 'In collection');
      expect(cta.icon, Icons.check_rounded);
      expect(cta.enabled, isFalse);
      expect(cta.usePrimaryTint, isFalse);
      expect(cta.isAddable, isFalse);
    });

    test('addable compact trailing uses Add label and primary tint', () {
      const match = CollectionSeriesOwnershipMatch.notOwned();
      final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
        match,
        layout: CollectionSeriesShelfCtaLayout.compactTrailing,
      );

      expect(cta.visualState, OwnershipShelfCtaVisualState.addable);
      expect(cta.label, 'Add');
      expect(cta.icon, Icons.add_rounded);
      expect(cta.enabled, isTrue);
      expect(cta.usePrimaryTint, isTrue);
    });

    test('same ownership produces aligned compact and home icon semantics', () {
      const match = CollectionSeriesOwnershipMatch.owned(
        kind: CollectionSeriesOwnershipMatchKind.canonicalBrandSeries,
        matchedSeriesId: 's1',
      );
      final compact = CollectionSeriesShelfCtaPresentation.fromOwnership(
        match,
        layout: CollectionSeriesShelfCtaLayout.compactTrailing,
      );
      final icon = CollectionSeriesShelfCtaPresentation.fromOwnership(
        match,
        layout: CollectionSeriesShelfCtaLayout.homeReleaseIcon,
      );

      expect(compact.isOwned, isTrue);
      expect(icon.isOwned, isTrue);
      expect(compact.usePrimaryTint, isFalse);
      expect(icon.usePrimaryTint, isFalse);
      expect(icon.icon, isNot(Icons.add_rounded));
      expect(icon.icon, isNot(Icons.add_circle_outline_rounded));
    });

    test('resolve uses shared ownership matcher for canonical shelf rows', () {
      const snap = CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 'user-row',
            name: 'Pinky Energy',
            brand: 'TOP TOY',
            ipName: 'Nommi',
            figures: const [],
            shelfAccent: Color(0xFFE4F2EA),
          ),
        ],
        figureStates: {},
      );

      final cta = CollectionSeriesShelfCtaPresentation.resolve(
        snapshot: snap,
        layout: CollectionSeriesShelfCtaLayout.compactTrailing,
        catalogTemplateId: 'nommi_pinky_energy_series',
        seriesName: 'Pinky Energy',
        brandName: 'TOP TOY',
      );

      expect(cta.isOwned, isTrue);
      expect(cta.label, 'In collection');
    });

    test('previewSticky owned shows In collection and is not addable', () {
      const match = CollectionSeriesOwnershipMatch.owned(
        kind: CollectionSeriesOwnershipMatchKind.canonicalBrandSeries,
        matchedSeriesId: 's1',
      );
      final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
        match,
        layout: CollectionSeriesShelfCtaLayout.previewSticky,
      );

      expect(cta.label, 'In collection');
      expect(cta.enabled, isFalse);
      expect(cta.isAddable, isFalse);
      expect(cta.icon, Icons.check_rounded);
    });

    test('previewSticky addable shows Add to shelf', () {
      const match = CollectionSeriesOwnershipMatch.notOwned();
      final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
        match,
        layout: CollectionSeriesShelfCtaLayout.previewSticky,
      );

      expect(cta.label, 'Add to shelf');
      expect(cta.enabled, isTrue);
      expect(cta.isAddable, isTrue);
    });
  });
}
