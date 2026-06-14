import 'package:blindbox_app/features/collection/data/collection_taxonomy_canonicalizer.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(CollectionTaxonomyCanonicalizer.resetIndexesForTest);

  test('registry indexes have no ambiguous brand or IP keys', () {
    expect(CollectionTaxonomyCanonicalizer.ambiguousBrandKeysForTest(), isEmpty);
    expect(CollectionTaxonomyCanonicalizer.ambiguousIpKeysForTest(), isEmpty);
  });

  group('resolveBrandFromUserInput', () {
    void expectBrand(
      String input, {
      required String displayLabel,
      required String taxonomyId,
      required bool matchedRegistry,
    }) {
      final result =
          CollectionTaxonomyCanonicalizer.resolveBrandFromUserInput(input);
      expect(result.displayLabel, displayLabel);
      expect(result.taxonomyId, taxonomyId);
      expect(result.matchedRegistry, matchedRegistry);
    }

    test('dpl variants resolve to Cureplaneta', () {
      expectBrand(
        'dpl',
        displayLabel: 'Cureplaneta',
        taxonomyId: 'dpl',
        matchedRegistry: true,
      );
      expectBrand(
        'DPL',
        displayLabel: 'Cureplaneta',
        taxonomyId: 'dpl',
        matchedRegistry: true,
      );
      expectBrand(
        'CUREPLANETA',
        displayLabel: 'Cureplaneta',
        taxonomyId: 'dpl',
        matchedRegistry: true,
      );
      expectBrand(
        'Cureplaneta',
        displayLabel: 'Cureplaneta',
        taxonomyId: 'dpl',
        matchedRegistry: true,
      );
      expectBrand(
        'CurePlaneta',
        displayLabel: 'Cureplaneta',
        taxonomyId: 'dpl',
        matchedRegistry: true,
      );
      expectBrand(
        'Cure Planeta',
        displayLabel: 'Cureplaneta',
        taxonomyId: 'dpl',
        matchedRegistry: true,
      );
    });

    test('POP MART variants resolve to POP MART', () {
      expectBrand(
        'POPMART',
        displayLabel: 'POP MART',
        taxonomyId: 'pop_mart',
        matchedRegistry: true,
      );
      expectBrand(
        'POP MART',
        displayLabel: 'POP MART',
        taxonomyId: 'pop_mart',
        matchedRegistry: true,
      );
    });

    test('POP does not match registry', () {
      expectBrand(
        'POP',
        displayLabel: 'POP',
        taxonomyId: CustomSeriesConventions.brandIdFromDisplay('POP'),
        matchedRegistry: false,
      );
    });

    test('empty brand resolves to Independent', () {
      final result =
          CollectionTaxonomyCanonicalizer.resolveBrandFromUserInput(null);
      expect(result.displayLabel, 'Independent');
      expect(result.taxonomyId, CustomSeriesConventions.independentBrandId);
      expect(result.matchedRegistry, isFalse);
    });
  });

  group('resolveIpFromUserInput', () {
    void expectIp(
      String input, {
      required String displayLabel,
      required String taxonomyId,
      required bool matchedRegistry,
    }) {
      final result =
          CollectionTaxonomyCanonicalizer.resolveIpFromUserInput(input);
      expect(result.displayLabel, displayLabel);
      expect(result.taxonomyId, taxonomyId);
      expect(result.matchedRegistry, matchedRegistry);
    }

    test('Baby Three variants resolve to Baby Three', () {
      for (final input in [
        'babythree',
        'BABYTHREE',
        'Baby Three',
        'baby_three',
      ]) {
        expectIp(
          input,
          displayLabel: 'Baby Three',
          taxonomyId: 'baby_three',
          matchedRegistry: true,
        );
      }
    });

    test('Hirono and LABUBU resolve to registry IPs', () {
      expectIp(
        'Hirono',
        displayLabel: 'Hirono',
        taxonomyId: 'hirono',
        matchedRegistry: true,
      );
      expectIp(
        'LABUBU',
        displayLabel: 'THE MONSTERS',
        taxonomyId: 'the_monsters',
        matchedRegistry: true,
      );
    });

    test('partial tokens do not match registry', () {
      expectIp(
        'baby',
        displayLabel: 'baby',
        taxonomyId: 'baby',
        matchedRegistry: false,
      );
      expectIp(
        'Custom Labubu Fan Art',
        displayLabel: 'Custom Labubu Fan Art',
        taxonomyId: 'custom_labubu_fan_art',
        matchedRegistry: false,
      );
    });
  });
}
